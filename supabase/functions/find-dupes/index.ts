import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ReferenceInput {
  name: string
  brand: string
  accords: string[]
  topNotes: string[]
  heartNotes: string[]
  baseNotes: string[]
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  try {
    const {
      reference,
      limit = 8,
      referencePriceSar,
    }: { reference: ReferenceInput; limit?: number; referencePriceSar?: number } =
      await req.json()

    if (!reference?.name) {
      return new Response(JSON.stringify({ error: 'reference.name is required' }), {
        status: 400,
        headers: { ...cors, 'Content-Type': 'application/json' },
      })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // 1. Fetch candidates that share at least one accord with the reference
    const accordFilters = (reference.accords ?? [])
      .map((a) => `accords.cs.["${a}"]`)
      .join(',')

    let query = supabase
      .from('fragrances')
      .select('source_id, name, brand, accords, notes, rating')
      .order('popularity_score', { ascending: false })
      .limit(100)

    if (accordFilters) {
      query = query.or(accordFilters)
    }

    const { data: pool, error } = await query
    if (error) throw error

    const candidates = (pool ?? []).filter(
      (p) => !(p.name === reference.name && p.brand === reference.brand),
    )

    // 2. Build candidate list for the prompt
    const candidateLines = candidates
      .slice(0, 90)
      .map((p) => {
        const accords = (p.accords ?? []).slice(0, 5).join(', ')
        const notes = p.notes ?? {}
        const top = (notes.top ?? []).slice(0, 3).join(', ')
        return `${p.source_id}: ${p.brand} – ${p.name} | accords: ${accords}${top ? ' | top notes: ' + top : ''}`
      })
      .join('\n')

    const refNotesSummary = [
      reference.topNotes?.length ? `top: ${reference.topNotes.slice(0, 4).join(', ')}` : '',
      reference.heartNotes?.length ? `heart: ${reference.heartNotes.slice(0, 4).join(', ')}` : '',
      reference.baseNotes?.length ? `base: ${reference.baseNotes.slice(0, 4).join(', ')}` : '',
    ]
      .filter(Boolean)
      .join(' | ')

    const refAccordsSummary = (reference.accords ?? []).join(', ')

    const refPriceContext = referencePriceSar
      ? `Actual reference perfume price: ${referencePriceSar} SAR.`
      : `Also estimate the reference perfume price in SAR (reference_price_range_sar).`

    // 3. Build English prompt
    const prompt =
`You are a fragrance expert specializing in alternatives, clones, and market pricing.

Reference perfume: ${reference.brand} – ${reference.name}
Accords: ${refAccordsSummary}
${refNotesSummary ? 'Notes: ' + refNotesSummary : ''}
${refPriceContext}

Required:
1. Estimate the reference perfume price range in SAR (reference_price_range_sar).
2. From the following list, choose the best ${limit} perfumes that resemble the reference or are considered clones/alternatives.
3. For each alternative, estimate its SAR price range (price_range_sar).

Focus on matching accords, notes, and the perfume's overall character.

List (id: brand – name | data):
${candidateLines}

Return JSON only, with no surrounding text:
{
  "reference_price_range_sar": "1800-2500",
  "dupes": [
    {"id":"...","reason":"short English reason, 12 words or fewer","similarity":85,"price_range_sar":"150-300"}
  ]
}

Sort from highest to lowest similarity. similarity: number from 0 to 100.`

    // 4. Call OpenAI
    const openaiRes = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('OPENAI_API_KEY')!}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        max_tokens: 800,
        temperature: 0.2,
        messages: [{ role: 'user', content: prompt }],
      }),
    })

    const openaiData = await openaiRes.json()
    const rawText: string = openaiData.choices?.[0]?.message?.content?.trim() ?? ''

    // Extract the JSON object from the response
    const match = rawText.match(/\{[\s\S]*\}/)
    if (!match) throw new Error('AI response did not contain a JSON object')

    const parsed: {
      reference_price_range_sar?: string
      dupes: { id: string; reason: string; similarity: number; price_range_sar?: string }[]
    } = JSON.parse(match[0])

    const picks = parsed.dupes ?? []
    const referencePriceRangeSar = referencePriceSar
      ? `${referencePriceSar}` // user-provided exact price takes precedence
      : (parsed.reference_price_range_sar ?? null)

    // 5. Fetch full fragrance rows for the picked IDs
    const ids = picks.map((p) => p.id)
    const { data: chosen } = await supabase
      .from('fragrances')
      .select(
        'source_id, source_url, name, brand, image_url, fallback_image_url, ' +
          'year, gender, rating, rating_votes, accords',
      )
      .in('source_id', ids)

    // 6. Merge AI metadata, preserve ranking order
    const dupes = picks
      .map((pick) => {
        const row = (chosen ?? []).find((c) => c.source_id === pick.id)
        if (!row) return null
        return {
          ...row,
          ai_reason: pick.reason,
          similarity_pct: pick.similarity,
          price_range_sar: pick.price_range_sar ?? null,
        }
      })
      .filter(Boolean)

    return new Response(
      JSON.stringify({ reference_price_range_sar: referencePriceRangeSar, dupes }),
      { headers: { ...cors, 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }
})
