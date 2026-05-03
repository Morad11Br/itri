import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  try {
    const { occasion, style, gender, season, intensity } = await req.json()

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // 1. Pull 80 popular candidates; optionally narrow by gender
    let query = supabase
      .from('fragrances')
      .select('source_id, name, brand, accords, rating')
      .order('popularity_score', { ascending: false })
      .limit(80)

    const genderValues: Record<string, string[]> = {
      men:    ['men', 'Men', 'male', 'for men', 'For Men', 'gender_for_men'],
      women:  ['women', 'Women', 'female', 'for women', 'For Women', 'gender_for_women'],
      unisex: ['unisex', 'Unisex', 'women and men', 'Women And Men'],
    }
    if (gender && genderValues[gender]) {
      query = query.in('gender', genderValues[gender])
    }

    const { data: perfumes, error } = await query
    if (error) throw error

    // 2. Build English prompt
    const list = (perfumes ?? [])
      .map(p => `${p.source_id}: ${p.brand} – ${p.name} (${(p.accords ?? []).slice(0, 4).join(', ')})`)
      .join('\n')

    const genderLabel = gender === 'men' ? 'men' : gender === 'women' ? 'women' : 'unisex'

    const prompt =
`You are a fragrance expert. Choose the best 5 perfumes from the list based on the user's preferences:
- Occasion: ${occasion}
- Season: ${season ?? 'not specified'}
- Style: ${style}
- Gender: ${genderLabel}
- Desired intensity: ${intensity ?? 'medium'}

List (id: brand – name (notes)):
${list}

Return JSON only, with no surrounding text:
[{"id":"...","reason":"short English reason, 12 words or fewer"}]`

    // 3. Ask OpenAI
    const openaiRes = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('OPENAI_API_KEY')!}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        max_tokens: 512,
        messages: [{ role: 'user', content: prompt }],
      }),
    })

    const openaiData = await openaiRes.json()
    const rawText: string = openaiData.choices[0].message.content.trim()

    const match = rawText.match(/\[[\s\S]*\]/)
    if (!match) throw new Error('OpenAI response did not contain a JSON array')

    const picks: { id: string; reason: string }[] = JSON.parse(match[0])
    const ids = picks.map(p => p.id)

    // 4. Fetch full rows for chosen IDs
    const { data: chosen } = await supabase
      .from('fragrances')
      .select(
        'source_id, source_url, name, brand, image_url, fallback_image_url, ' +
        'year, gender, rating, rating_votes, accords',
      )
      .in('source_id', ids)

    // 5. Merge reasons, preserve Claude's ranking order
    const results = picks
      .map(pick => {
        const row = (chosen ?? []).find(c => c.source_id === pick.id)
        if (!row) return null
        return { ...row, ai_reason: pick.reason }
      })
      .filter(Boolean)

    return new Response(JSON.stringify(results), {
      headers: { ...cors, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }
})
