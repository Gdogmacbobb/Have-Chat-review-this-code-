import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.21.0';
import Stripe from 'https://esm.sh/stripe@12.0.0?target=deno';

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

serve(async (req) => {
    // Handle CORS preflight request
    if (req.method === 'OPTIONS') {
        return new Response('ok', {
            headers: corsHeaders
        });
    }

    try {
        // Create a Supabase client
        const supabaseUrl = Deno.env.get('SUPABASE_URL');
        const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY');
        const supabase = createClient(supabaseUrl, supabaseKey);

        // Create a Stripe client
        const stripeKey = Deno.env.get('STRIPE_SECRET_KEY');
        const stripe = new Stripe(stripeKey);

        // Get the request body
<<<<<<< HEAD
        const { amount, currency, donation_id, use_checkout, success_url, cancel_url } = await req.json();
=======
        const { amount, currency, donation_id } = await req.json();
>>>>>>> b1f9c438f65d3f7093efb1d909f7b1e8e83c8cb5

        // Validate input
        if (!amount || amount <= 0) {
            throw new Error('Invalid amount');
        }

        if (!donation_id) {
            throw new Error('Donation ID required');
        }

<<<<<<< HEAD
        // If checkout session is requested (PCI-DSS compliant approach)
        if (use_checkout) {
            if (!success_url || !cancel_url) {
                throw new Error('Success and cancel URLs required for checkout session');
            }

            const session = await stripe.checkout.sessions.create({
                payment_method_types: ['card'],
                line_items: [{
                    price_data: {
                        currency: currency || 'usd',
                        product_data: {
                            name: 'YNFNY Performer Support',
                            description: 'Support a street performer in New York',
                        },
                        unit_amount: Math.round(amount * 100), // Convert dollars to cents
                    },
                    quantity: 1,
                }],
                mode: 'payment',
                success_url: success_url,
                cancel_url: cancel_url,
                metadata: {
                    donation_id: donation_id,
                    platform: 'YNFNY'
                },
            });

            return new Response(JSON.stringify({
                checkout_url: session.url,
                session_id: session.id,
                amount: Math.round(amount * 100),
                currency: currency || 'usd',
            }), {
                headers: {
                    ...corsHeaders,
                    'Content-Type': 'application/json'
                },
                status: 200
            });
        } else {
            // Create a Stripe payment intent (for direct integration)
            const paymentIntent = await stripe.paymentIntents.create({
                amount: Math.round(amount * 100), // Convert dollars to cents - Stripe expects amount in smallest currency unit
                currency: currency || 'usd',
                automatic_payment_methods: {
                    enabled: true,
                },
                metadata: {
                    donation_id: donation_id,
                    platform: 'YNFNY'
                },
            });

            // Return the Stripe payment intent
            return new Response(JSON.stringify({
                payment_intent_id: paymentIntent.id,
                client_secret: paymentIntent.client_secret,
                amount: paymentIntent.amount,
                currency: paymentIntent.currency,
            }), {
                headers: {
                    ...corsHeaders,
                    'Content-Type': 'application/json'
                },
                status: 200
            });
        }
=======
        // Create a Stripe checkout session or payment intent
        const paymentIntent = await stripe.paymentIntents.create({
            amount: Math.round(amount), // Stripe expects amount in smallest currency unit (cents)
            currency: currency || 'usd',
            automatic_payment_methods: {
                enabled: true,
            },
            metadata: {
                donation_id: donation_id,
                platform: 'YNFNY'
            },
        });

        // Return the Stripe payment intent
        return new Response(JSON.stringify({
            payment_intent_id: paymentIntent.id,
            client_secret: paymentIntent.client_secret,
            amount: paymentIntent.amount,
            currency: paymentIntent.currency,
        }), {
            headers: {
                ...corsHeaders,
                'Content-Type': 'application/json'
            },
            status: 200
        });
>>>>>>> b1f9c438f65d3f7093efb1d909f7b1e8e83c8cb5

    } catch (error) {
        return new Response(JSON.stringify({
            error: error.message
        }), {
            headers: {
                ...corsHeaders,
                'Content-Type': 'application/json'
            },
            status: 400
        });
    }
});