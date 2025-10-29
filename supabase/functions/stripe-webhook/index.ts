import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.21.0';
import Stripe from 'https://esm.sh/stripe@12.0.0?target=deno';

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, stripe-signature'
};

serve(async (req) => {
    // Handle CORS preflight request
    if (req.method === 'OPTIONS') {
        return new Response('ok', {
            headers: corsHeaders
        });
    }

    if (req.method !== 'POST') {
        return new Response('Method not allowed', { status: 405 });
    }

    try {
        // Create Supabase client
        const supabaseUrl = Deno.env.get('SUPABASE_URL');
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
        const supabase = createClient(supabaseUrl!, supabaseServiceKey!);

        // Create Stripe client
        const stripeKey = Deno.env.get('STRIPE_SECRET_KEY');
        const stripe = new Stripe(stripeKey!);

        // Get webhook secret for signature verification
        const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET');
        
        if (!webhookSecret) {
            console.error('STRIPE_WEBHOOK_SECRET not configured');
            return new Response('Webhook secret not configured', { status: 500 });
        }

        // Get the raw body and signature
        const body = await req.text();
        const signature = req.headers.get('stripe-signature');

        if (!signature) {
            console.error('No Stripe signature found');
            return new Response('No signature', { status: 400 });
        }

        let event: Stripe.Event;
        
        try {
            // Verify webhook signature
            event = stripe.webhooks.constructEvent(body, signature, webhookSecret);
            console.log(`✅ WEBHOOK: Verified event type: ${event.type}`);
        } catch (err) {
            console.error(`❌ WEBHOOK: Signature verification failed: ${err}`);
            return new Response('Invalid signature', { status: 400 });
        }

        // Handle the event
        switch (event.type) {
            case 'payment_intent.succeeded':
                await handlePaymentIntentSucceeded(supabase, event.data.object as Stripe.PaymentIntent);
                break;
            case 'payment_intent.payment_failed':
                await handlePaymentIntentFailed(supabase, event.data.object as Stripe.PaymentIntent);
                break;
            default:
                console.log(`🔄 WEBHOOK: Unhandled event type: ${event.type}`);
        }

        return new Response(JSON.stringify({ received: true }), {
            headers: {
                ...corsHeaders,
                'Content-Type': 'application/json'
            },
            status: 200
        });

    } catch (error) {
        console.error(`❌ WEBHOOK: Error processing webhook: ${error}`);
        return new Response(JSON.stringify({
            error: 'Webhook processing failed'
        }), {
            headers: {
                ...corsHeaders,
                'Content-Type': 'application/json'
            },
            status: 500
        });
    }
});

async function handlePaymentIntentSucceeded(supabase: any, paymentIntent: Stripe.PaymentIntent) {
    try {
        console.log(`💰 WEBHOOK: Payment succeeded: ${paymentIntent.id}`);
        
        const donationId = paymentIntent.metadata.donation_id;
        if (!donationId) {
            console.error('No donation_id in payment intent metadata');
            return;
        }

        console.log(`🔄 WEBHOOK: Processing donation completion: ${donationId}`);

        // Update donation status to completed with idempotency check
        const { data: donation, error: donationError } = await supabase
            .from('donations')
            .select('*')
            .eq('id', donationId)
            .eq('stripe_payment_intent_id', paymentIntent.id)
            .single();

        if (donationError) {
            console.error(`❌ WEBHOOK: Error finding donation: ${donationError.message}`);
            return;
        }

        if (donation.status === 'completed') {
            console.log(`✅ WEBHOOK: Donation ${donationId} already completed - idempotent`);
            return;
        }

        // CRITICAL SECURITY: Validate payment amount matches donation amount
        // PaymentIntent amount is in cents, donation amount is in dollars
        const expectedAmountCents = Math.round(donation.amount * 100);
        if (paymentIntent.amount !== expectedAmountCents) {
            console.error(`❌ WEBHOOK: SECURITY VIOLATION - Payment amount mismatch! Expected: ${expectedAmountCents} cents ($${donation.amount}), Got: ${paymentIntent.amount} cents`);
            
            // Mark donation as failed due to amount mismatch
            await supabase
                .from('donations')
                .update({
                    status: 'failed',
                    updated_at: new Date().toISOString(),
                })
                .eq('id', donationId);
            
            return;
        }
        
        console.log(`✅ WEBHOOK: Amount validation passed - ${paymentIntent.amount} cents matches expected ${expectedAmountCents} cents`);

        // Calculate platform fee and net amount
        const amount = donation.amount;
        const platformFeeRate = 0.05;
        const netAmount = amount * (1 - platformFeeRate);

        // Start transaction to update donation and recipient balance atomically
        const { error: updateError } = await supabase
            .from('donations')
            .update({
                status: 'completed',
                updated_at: new Date().toISOString(),
            })
            .eq('id', donationId);

        if (updateError) {
            console.error(`❌ WEBHOOK: Error updating donation status: ${updateError.message}`);
            return;
        }

        // Update recipient's total donations
        const { error: balanceError } = await supabase.rpc('increment_user_donations', {
            user_id: donation.recipient_id,
            amount: netAmount
        });

        if (balanceError) {
            console.error(`❌ WEBHOOK: Error updating recipient balance: ${balanceError.message}`);
            // Don't return - continue with notification
        }

        // Create notification for recipient
        const { error: notificationError } = await supabase
            .from('notifications')
            .insert({
                user_id: donation.recipient_id,
                type: 'donation',
                title: 'Donation Received!',
                message: `You received a $${amount.toFixed(2)} donation!`,
                data: {
                    donation_id: donationId,
                    amount: amount,
                    net_amount: netAmount,
                },
            });

        if (notificationError) {
            console.error(`❌ WEBHOOK: Error creating notification: ${notificationError.message}`);
        }

        console.log(`🎉 WEBHOOK: Successfully processed donation ${donationId} - $${amount} (net: $${netAmount.toFixed(2)})`);

    } catch (error) {
        console.error(`❌ WEBHOOK: Error in handlePaymentIntentSucceeded: ${error}`);
    }
}

async function handlePaymentIntentFailed(supabase: any, paymentIntent: Stripe.PaymentIntent) {
    try {
        console.log(`❌ WEBHOOK: Payment failed: ${paymentIntent.id}`);
        
        const donationId = paymentIntent.metadata.donation_id;
        if (!donationId) {
            console.error('No donation_id in payment intent metadata');
            return;
        }

        // Update donation status to failed
        const { error } = await supabase
            .from('donations')
            .update({
                status: 'failed',
                updated_at: new Date().toISOString(),
            })
            .eq('id', donationId);

        if (error) {
            console.error(`❌ WEBHOOK: Error updating failed donation: ${error.message}`);
        } else {
            console.log(`🔄 WEBHOOK: Marked donation ${donationId} as failed`);
        }

    } catch (error) {
        console.error(`❌ WEBHOOK: Error in handlePaymentIntentFailed: ${error}`);
    }
}