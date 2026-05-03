import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  try {
    const { image } = await req.json()
    if (!image || typeof image !== 'string') {
      return new Response(JSON.stringify({ error: 'image (base64 data URL) is required' }), {
        status: 400,
        headers: { ...cors, 'Content-Type': 'application/json' },
      })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // 1. Ask OpenAI Vision to identify the perfume from the image
    const openaiRes = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('OPENAI_API_KEY')!}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o',
        max_tokens: 256,
        temperature: 0.2,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: `You are a perfume expert. Look at this image of a perfume bottle or box and identify the brand and perfume name.

Return ONLY a JSON object in this exact format, with no markdown or extra text:
{"brand":"Brand Name","name":"Perfume Name","confidence":"high|medium|low"}

If you cannot clearly identify it, return:
{"brand":"","name":"","confidence":"low"}`,
              },
              {
                type: 'image_url',
                image_url: { url: image, detail: 'low' },
              },
            ],
          },
        ],
      }),
    })

    const openaiData = await openaiRes.json()
    const rawText: string = openaiData.choices?.[0]?.message?.content?.trim() ?? ''

    // Extract JSON from response
    const match = rawText.match(/\{[\s\S]*\}/)
    if (!match) {
      return new Response(JSON.stringify({ error: 'Could not parse AI response', raw: rawText }), {
        status: 500,
        headers: { ...cors, 'Content-Type': 'application/json' },
      })
    }

    const parsed: { brand?: string; name?: string; confidence?: string } = JSON.parse(match[0])
    const brand = (parsed.brand ?? '').trim()
    const name = (parsed.name ?? '').trim()
    const confidence = (parsed.confidence ?? 'low').toLowerCase()

    if (!brand && !name) {
      return new Response(
        JSON.stringify({ brand: '', name: '', confidence: 'low', matches: [] }),
        { headers: { ...cors, 'Content-Type': 'application/json' } },
      )
    }

    // 2. Search Supabase for matching perfumes
    // Try exact-ish match first, then broader search
    let query = supabase
      .from('fragrances')
      .select(
        'source_id, source_url, name, brand, image_url, fallback_image_url, ' +
        'year, gender, rating, rating_votes, accords',
      )

    if (brand && name) {
      query = query.or(`brand.ilike.%${brand}%,name.ilike.%${name}%`)
    } else if (brand) {
      query = query.ilike('brand', `%${brand}%`)
    } else if (name) {
      query = query.ilike('name', `%${name}%`)
    }

    const { data: matches, error } = await query.limit(5)
    if (error) throw error

    // Rank matches: exact name matches first, then brand matches
    const ranked = (matches ?? []).sort((a, b) => {
      const aNameMatch = a.name?.toLowerCase().includes(name.toLowerCase()) ? 2 : 0
      const bNameMatch = b.name?.toLowerCase().includes(name.toLowerCase()) ? 2 : 0
      const aBrandMatch = a.brand?.toLowerCase().includes(brand.toLowerCase()) ? 1 : 0
      const bBrandMatch = b.brand?.toLowerCase().includes(brand.toLowerCase()) ? 1 : 0
      return (bNameMatch + bBrandMatch) - (aNameMatch + aBrandMatch)
    })

    return new Response(
      JSON.stringify({ brand, name, confidence, matches: ranked }),
      { headers: { ...cors, 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }
})
