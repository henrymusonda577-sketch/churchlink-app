import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const supabase = createClient(supabaseUrl, supabaseServiceKey)

const mtnApiKey = Deno.env.get('MTN_API_KEY')!
const mtnSubscriptionKey = Deno.env.get('MTN_SUBSCRIPTION_KEY')!
const mtnBaseUrl = Deno.env.get('MTN_BASE_URL')!
const mtnCurrency = Deno.env.get('MTN_CURRENCY')!

// Function to get MTN auth header
function getMtnAuth(): string {
  return `Basic ${btoa(`${mtnApiKey}:`)}`
}

// Function to initiate disbursement
async function initiateDisbursement(reference: string, msisdn: string, amount: number): Promise<any> {
  const response = await fetch(`${mtnBaseUrl}/disbursement/v1_0/transfer`, {
    method: 'POST',
    headers: {
      'Authorization': getMtnAuth(),
      'Ocp-Apim-Subscription-Key': mtnSubscriptionKey,
      'Content-Type': 'application/json',
      'X-Reference-Id': reference
    },
    body: JSON.stringify({
      amount: amount.toString(),
      currency: mtnCurrency,
      externalId: reference,
      payee: {
        partyIdType: "MSISDN",
        partyId: msisdn
      },
      payerMessage: "Payment transfer",
      payeeNote: "Mobile money transfer"
    })
  })

  if (!response.ok) {
    const errorText = await response.text()
    throw new Error(`Disbursement failed: ${response.status} ${errorText}`)
  }

  return await response.json()
}

serve(async (req) => {
  try {
    // Get user from auth
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
    }

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)

    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid token' }), { status: 401 })
    }

    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 })
    }

    const { amount, phoneNumber, description } = await req.json()

    if (!amount || !phoneNumber) {
      return new Response(JSON.stringify({ error: 'Amount and phone number required' }), { status: 400 })
    }

    // Check wallet balance
    const { data: wallet, error: walletError } = await supabase
      .rpc('get_or_create_wallet', { p_user_id: user.id })

    if (walletError) {
      console.error('Wallet error:', walletError)
      return new Response(JSON.stringify({ error: 'Failed to access wallet' }), { status: 500 })
    }

    const { data: balanceData, error: balanceError } = await supabase
      .from('wallets')
      .select('balance')
      .eq('user_id', user.id)
      .single()

    if (balanceError || !balanceData) {
      return new Response(JSON.stringify({ error: 'Wallet not found' }), { status: 404 })
    }

    if (balanceData.balance < amount) {
      return new Response(JSON.stringify({ error: 'Insufficient balance' }), { status: 400 })
    }

    // Get user tier and calculate admin fee
    const { data: userTierData, error: tierError } = await supabase
      .rpc('get_user_tier', { p_user_id: user.id })

    if (tierError) {
      console.error('Tier error:', tierError)
      return new Response(JSON.stringify({ error: 'Failed to get user tier' }), { status: 500 })
    }

    const userTier = userTierData || 'basic'
    const { data: adminFeeData, error: feeError } = await supabase
      .rpc('calculate_admin_fee', { p_amount: amount, p_user_tier: userTier })

    if (feeError) {
      console.error('Fee calculation error:', feeError)
      return new Response(JSON.stringify({ error: 'Failed to calculate fee' }), { status: 500 })
    }

    const adminAmount = adminFeeData || 0
    const recipientAmount = Math.round((amount - adminAmount) * 100) / 100
    const adminPhone = '0973644384' // Admin wallet number

    // Generate references
    const baseRef = `mtn_send_${user.id}_${Date.now()}`
    const recipientRef = `${baseRef}_recipient`
    const adminRef = `${baseRef}_admin`

    // Create transaction records for both transfers
    const transactions = [
      {
        user_id: user.id,
        type: 'send',
        amount: recipientAmount,
        currency: mtnCurrency,
        status: 'pending',
        reference: recipientRef,
        provider: 'mtn',
        description: `${description} (to recipient)`
      },
      {
        user_id: user.id,
        type: 'send',
        amount: adminAmount,
        currency: mtnCurrency,
        status: 'pending',
        reference: adminRef,
        provider: 'mtn',
        description: `${description} (admin fee)`
      }
    ]

    const { data: insertedTransactions, error: txError } = await supabase
      .from('transactions')
      .insert(transactions)
      .select()

    if (txError) {
      console.error('Transaction insert error:', txError)
      return new Response(JSON.stringify({ error: 'Failed to create transactions' }), { status: 500 })
    }

    try {
      // Deduct full amount from wallet
      await supabase.rpc('update_wallet_balance', {
        p_user_id: user.id,
        p_amount: amount,
        p_type: 'send'
      })

      // Initiate disbursements
      const recipientResult = await initiateDisbursement(recipientRef, phoneNumber, recipientAmount)
      const adminResult = await initiateDisbursement(adminRef, adminPhone, adminAmount)

      // Update transactions with external IDs and status
      await supabase
        .from('transactions')
        .update({
          external_id: recipientRef,
          status: 'processing'
        })
        .eq('reference', recipientRef)

      await supabase
        .from('transactions')
        .update({
          external_id: adminRef,
          status: 'processing'
        })
        .eq('reference', adminRef)

      return new Response(JSON.stringify({
        success: true,
        recipientTransactionId: insertedTransactions[0].id,
        adminTransactionId: insertedTransactions[1].id,
        recipientReference: recipientRef,
        adminReference: adminRef,
        status: 'processing'
      }), { status: 200 })

    } catch (apiError) {
      console.error('MTN API error:', apiError)

      // Refund full amount to wallet
      await supabase.rpc('update_wallet_balance', {
        p_user_id: user.id,
        p_amount: amount,
        p_type: 'receive'
      })

      // Update all transactions to failed
      await supabase
        .from('transactions')
        .update({ status: 'failed' })
        .in('reference', [recipientRef, adminRef])

      return new Response(JSON.stringify({ error: 'Payment initiation failed' }), { status: 500 })
    }

  } catch (error) {
    console.error('Server error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), { status: 500 })
  }
})