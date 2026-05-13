import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const SYSTEM_PROMPT = `You are a fragrance pricing expert. Classify each perfume into exactly one of these 4 tiers based on typical retail price and brand positioning:

- budget: Under $30 retail. Brands like Lattafa, Rasasi, Armaf, Al Rehab, Swiss Arabian, Club De Nuit, Sterling Parfums, Afnan, Ard Al Zaafaran, Al Haramain, Ajmal, Nabeel, Sapil, Riiffs, Maison Alhambra, Milestone, Emper, Vurv, Asdaaf, Fragrance World, Flavia, Paris Corner, Orientica, Byron, Aldehyde, Alt, Dossier, Oakcha, Oil Perfumery, Dual Scent, French Factor, La Rive, Jovan, Coty, Avon, Mary Kay, Reminiscence, S.Oliver, Benetton, Arabian Oud.
- mid: $30–$100 retail. Brands like Versace, Hugo Boss, Montblanc, Calvin Klein, Davidoff, Lacoste, Prada, Coach, Guess, Nautica, Kenneth Cole, Perry Ellis, Azzaro, Issey Miyake, Narciso Rodriguez, Carolina Herrera, Paco Rabanne, Jean Paul Gaultier, Dolce Gabbana, Ralph Lauren, Salvatore Ferragamo, Bvlgari, Burberry, Dunhill, Bentley, Jaguar, Mercedes Benz, Mancera, Banana Republic, Gucci, Lancome, Elizabeth Arden, Kenzo, Loewe, Marc Jacobs, Diesel, DKNY, Escada, Joop, Cacharel, Chopard, Ferrari.
- premium: $100–$250 retail. Brands like Dior, Chanel, YSL, Givenchy, Prada, Armani, Guerlain, Hermes, Lanvin, Cartier, Valentino, Coach, Jimmy Choo, Tiffany, Elie Saab, Narciso Rodriguez, Viktor, Roja.
- niche: Above $250 retail. Brands like Tom Ford, Creed, Amouage, Maison Francis Kurkdjian, MFK, Initio, Xerjoff, Parfums de Marly, Byredo, Diptyque, Le Labo, Frederic Malle, Serge Lutens, Kilian, Clive Christian, Roja Dove, Bond No. 9, Nasomatto, Ormonde Jayne, Neela Vermeire, Boadicea, Fort & Manle, Tauer, Dusita, Strangers, Hiba, Ensar Oud.

Use brand as the primary signal, but also consider the perfume name (e.g. "Private Blend", "Extrait", "Parfum" often indicate higher tiers).

Respond ONLY with a valid JSON object in this exact format — no markdown, no explanations:
{
  "results": [
    {"id":"<uuid>","tier":"budget"},
    ...
  ]
}
The "id" field must match exactly the id given in the input.`

const BATCH_SIZE = 50
const MAX_RETRIES = 3

interface PerfumeInput {
  id: string
  name: string
  brand: string
}

interface TierResult {
  id: string
  tier: string
}

async function callOpenAI(perfumes: PerfumeInput[]): Promise<TierResult[]> {
  const userContent = perfumes
    .map((p) => `id: ${p.id} | brand: ${p.brand} | name: ${p.name}`)
    .join('\n')

  const body = JSON.stringify({
    model: 'gpt-4o-mini',
    max_tokens: 1200,
    temperature: 0.1,
    messages: [
      { role: 'system', content: SYSTEM_PROMPT },
      { role: 'user', content: userContent },
    ],
  })

  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${Deno.env.get('OPENAI_API_KEY')!}`,
      'Content-Type': 'application/json',
    },
    body,
  })

  if (!res.ok) {
    const text = await res.text()
    throw new Error(`OpenAI HTTP ${res.status}: ${text}`)
  }

  const data = await res.json()
  const rawText: string = data.choices?.[0]?.message?.content?.trim() ?? ''

  // Strip markdown code fences if present
  const cleaned = rawText
    .replace(/^```json\s*/, '')
    .replace(/^```\s*/, '')
    .replace(/\s*```$/, '')

  const match = cleaned.match(/\{[\s\S]*\}/)
  if (!match) throw new Error('OpenAI response did not contain a JSON object')

  const parsed: { results?: TierResult[] } = JSON.parse(match[0])
  if (!Array.isArray(parsed.results)) {
    throw new Error('OpenAI JSON missing "results" array')
  }
  return parsed.results
}

async function classifyWithRetry(perfumes: PerfumeInput[]): Promise<TierResult[]> {
  let lastError: Error | null = null
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      return await callOpenAI(perfumes)
    } catch (e) {
      lastError = e instanceof Error ? e : new Error(String(e))
      if (attempt < MAX_RETRIES) {
        const delay = attempt * 1000
        console.log(`Batch retry ${attempt}/${MAX_RETRIES} after ${delay}ms: ${lastError.message}`)
        await new Promise((r) => setTimeout(r, delay))
      }
    }
  }
  throw lastError ?? new Error('Unknown OpenAI error after retries')
}

async function updateTiers(supabase: any, results: TierResult[]): Promise<{ updated: number; failed: number }> {
  let updated = 0
  let failed = 0

  for (const r of results) {
    const { error } = await supabase
      .from('fragrances')
      .update({ tier: r.tier })
      .eq('id', r.id)

    if (error) {
      console.error(`Failed to update ${r.id}:`, error)
      failed++
    } else {
      updated++
    }
  }

  return { updated, failed }
}

function chunkArray<T>(arr: T[], size: number): T[][] {
  const chunks: T[][] = []
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size))
  }
  return chunks
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  try {
    // ── GET: process all fragrances where tier IS NULL ───────────────────
    if (req.method === 'GET') {
      const { data, error } = await supabase
        .from('fragrances')
        .select('id, name, brand')
        .is('tier', null)

      if (error) throw error

      const perfumes: PerfumeInput[] = data ?? []
      if (perfumes.length === 0) {
        return new Response(
          JSON.stringify({ processed: 0, failed: 0, results: [] }),
          { headers: { ...cors, 'Content-Type': 'application/json' } },
        )
      }

      const batches = chunkArray(perfumes, BATCH_SIZE)
      const allResults: TierResult[] = []
      let totalFailed = 0
      let batchFailures = 0

      for (const batch of batches) {
        try {
          const classified = await classifyWithRetry(batch)
          const { updated, failed } = await updateTiers(supabase, classified)
          allResults.push(...classified)
          totalFailed += failed
          console.log(`Batch done: ${updated} updated, ${failed} DB errors`)
        } catch (e) {
          batchFailures++
          totalFailed += batch.length
          console.error(`Batch failed after retries: ${e instanceof Error ? e.message : String(e)}`)
        }
      }

      return new Response(
        JSON.stringify({
          processed: allResults.length,
          failed: totalFailed,
          results: allResults,
        }),
        { headers: { ...cors, 'Content-Type': 'application/json' } },
      )
    }

    // ── POST: classify provided fragrances ───────────────────────────────
    if (req.method === 'POST') {
      const { perfumes }: { perfumes?: PerfumeInput[] } = await req.json()

      if (!Array.isArray(perfumes) || perfumes.length === 0) {
        return new Response(
          JSON.stringify({ error: 'Expected body: { perfumes: [{id,name,brand}, ...] }' }),
          { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } },
        )
      }

      const batches = chunkArray(perfumes, BATCH_SIZE)
      const allResults: TierResult[] = []
      let totalFailed = 0
      let batchFailures = 0

      for (const batch of batches) {
        try {
          const classified = await classifyWithRetry(batch)
          const { updated, failed } = await updateTiers(supabase, classified)
          allResults.push(...classified)
          totalFailed += failed
          console.log(`Batch done: ${updated} updated, ${failed} DB errors`)
        } catch (e) {
          batchFailures++
          totalFailed += batch.length
          console.error(`Batch failed after retries: ${e instanceof Error ? e.message : String(e)}`)
        }
      }

      return new Response(
        JSON.stringify({
          processed: allResults.length,
          failed: totalFailed,
          results: allResults,
        }),
        { headers: { ...cors, 'Content-Type': 'application/json' } },
      )
    }

    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...cors, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    console.error('Unhandled error:', message)
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }
})
