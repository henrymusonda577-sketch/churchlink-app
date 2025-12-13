import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

console.log('Environment check:', {
  supabaseUrl: supabaseUrl ? 'present' : 'missing',
  supabaseServiceKey: supabaseServiceKey ? 'present' : 'missing'
})

const supabase = createClient(supabaseUrl, supabaseServiceKey)

const airtelClientId = Deno.env.get('AIRTEL_CLIENT_ID')!
const airtelClientSecret = Deno.env.get('AIRTEL_CLIENT_SECRET')!
const airtelBaseUrl = Deno.env.get('AIRTEL_BASE_URL')!
const airtelCountry = Deno.env.get('AIRTEL_COUNTRY')!
const airtelCurrency = Deno.env.get('AIRTEL_CURRENCY')!

// Function to get Airtel access token
async function getAirtelToken(): Promise<string> {
  const auth = btoa(`${airtelClientId}:${airtelClientSecret}`)
  const response = await fetch(`${airtelBaseUrl}/auth/oauth2/token`, {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${auth}`,
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: 'grant_type=client_credentials'
  })

  if (!response.ok) {
    throw new Error(`Failed to get token: ${response.statusText}`)
  }

  const data = await response.json()
  return data.access_token
}

// Function to initiate collection
async function initiateCollection(token: string, reference: string, msisdn: string, amount: number): Promise<any> {
  const response = await fetch(`${airtelBaseUrl}/merchant/v1/payments/`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      reference,
      subscriber: {
        country: airtelCountry,
        currency: airtelCurrency,
        msisdn
      },
      transaction: {
        amount,
        country: airtelCountry,
        currency: airtelCurrency,
        id: reference
      }
    })
  })

  if (!response.ok) {
    throw new Error(`Collection failed: ${response.statusText}`)
  }

  return await response.json()
}

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get user from auth
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const token = authHeader.replace('Bearer ', '')
    console.log('Authenticating user with token...')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)

    if (authError || !user) {
      console.error('Authentication failed:', { authError, user: user ? 'exists' : 'null' })
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log('User authenticated:', { userId: user.id, email: user.email })

    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const { amount, phoneNumber, description } = await req.json()

    if (!amount || !phoneNumber) {
      return new Response(JSON.stringify({ error: 'Amount and phone number required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Generate reference
    const reference = `airtel_recv_${user.id}_${Date.now()}`

    // Create transaction record
    console.log('Creating transaction with data:', {
      user_id: user.id,
      type: 'receive',
      amount,
      currency: airtelCurrency,
      status: 'pending',
      reference,
      provider: 'airtel',
      description
    })

    const { data: transaction, error: txError } = await supabase
      .from('transactions')
      .insert({
        user_id: user.id,
        type: 'receive',
        amount,
        currency: airtelCurrency,
        status: 'pending',
        reference,
        provider: 'airtel',
        description
      })
      .select()
      .single()

    if (txError) {
      console.error('Transaction insert error:', txError)
      console.error('Transaction insert error details:', {
        code: txError.code,
        details: txError.details,
        hint: txError.hint,
        message: txError.message
      })
      return new Response(JSON.stringify({
        error: 'Failed to create transaction',
        details: txError.message,
        code: txError.code
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log('Transaction created successfully:', transaction)

    try {
      // Get token and initiate collection
      const accessToken = await getAirtelToken()
      const result = await initiateCollection(accessToken, reference, phoneNumber, amount)

      // Update transaction with external ID
      await supabase
        .from('transactions')
        .update({
          external_id: result.transaction?.id || result.id,
          status: 'processing'
        })
        .eq('id', transaction.id)

      return new Response(JSON.stringify({
        success: true,
        transactionId: transaction.id,
        reference,
        status: 'processing'
      }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })

    } catch (apiError) {
      console.error('Airtel API error:', apiError)

      // Update transaction status to failed
      await supabase
        .from('transactions')
        .update({ status: 'failed' })
        .eq('id', transaction.id)

      return new Response(JSON.stringify({ error: 'Payment initiation failed' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

  } catch (error) {
    console.error('Server error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})