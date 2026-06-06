import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function getGroqApiKeys(): string[] {
  const keys: string[] = [];
  const addKeys = (raw: string | undefined) => {
    if (raw) {
      raw.split(",").forEach(k => {
        const trimmed = k.trim();
        if (trimmed && !keys.includes(trimmed)) {
          keys.push(trimmed);
        }
      });
    }
  };
  addKeys(Deno.env.get("GROQ_API_KEY"));
  addKeys(Deno.env.get("GROQ_API_KEY_1"));
  addKeys(Deno.env.get("GROQ_API_KEY_2"));
  addKeys(Deno.env.get("GROQ_API_KEY_3"));
  return keys;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Parse request payload
    const contentType = req.headers.get("content-type") || "";
    let action = "";
    let payload: any = {};

    if (contentType.includes("application/json")) {
      payload = await req.json();
      action = payload.action;
    } else if (contentType.includes("multipart/form-data")) {
      const formData = await req.formData();
      action = formData.get("action") as string;
      payload.formData = formData;
    }

    if (!action) {
      return new Response(JSON.stringify({ error: 'Missing action parameter' }), { status: 400, headers: corsHeaders });
    }

    // 2. Delegate based on action (no strict JWT auth required here to allow guest/free plan users)
    switch (action) {
      case "chat":
        return await handleChat(payload);
      case "transcribe":
        return await handleTranscribe(payload);
      case "emotion":
        return await handleEmotion(payload);
      default:
        return new Response(JSON.stringify({ error: `Unsupported action: ${action}` }), { status: 400, headers: corsHeaders });
    }

  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

// ── LLM Chat Completion Gateway (with transparent server-side fallback) ──
async function handleChat(payload: any) {
  const { messages, temperature, max_tokens, mode } = payload;
  
  // Get API keys from environment (supports comma-separated list of keys or individual variables)
  const groqKeys = getGroqApiKeys();
  const geminiApiKey = Deno.env.get("GEMINI_API_KEY") || "";
  const openRouterApiKey = Deno.env.get("OPENROUTER_API_KEY") || "";
  const openAiApiKey = Deno.env.get("OPENAI_API_KEY") || "";

  // Try Groq keys first (cascading fallback)
  for (const apiKey of groqKeys) {
    try {
      const model = mode === "restructure" ? "llama3-8b-8192" : "llama-3.3-70b-versatile";
      const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          model,
          messages,
          temperature: temperature ?? 0.7,
          max_tokens: max_tokens ?? 300,
        })
      });
      if (response.status === 200) {
        const data = await response.json();
        const content = data.choices[0].message.content;
        return new Response(JSON.stringify({ success: true, provider: "groq", content: content }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      } else {
        const errText = await response.text();
        console.warn(`Groq key failed, returned status ${response.status}: ${errText}`);
      }
    } catch (e: any) {
      console.warn("Groq key failed in Edge Function, trying next...", e.message);
    }
  }

  // Try Gemini
  if (geminiApiKey) {
    try {
      // Concatenate messages for simple model instruction
      const textPrompt = messages.map((m: any) => `${m.role}: ${m.content}`).join("\n\n");
      const model = mode === "restructure" ? "gemini-1.5-flash" : "gemini-2.0-flash";
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiApiKey}`;
      
      const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: textPrompt }] }],
          generationConfig: { maxOutputTokens: max_tokens ?? 300, temperature: temperature ?? 0.7 }
        })
      });
      if (response.status === 200) {
        const data = await response.json();
        const content = data.candidates[0].content.parts[0].text;
        return new Response(JSON.stringify({ success: true, provider: "gemini", content: content }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      } else {
        const errText = await response.text();
        console.warn(`Gemini request returned status ${response.status}: ${errText}`);
      }
    } catch (e: any) {
      console.warn("Gemini failed in Edge Function, trying fallback...", e.message);
    }
  }

  // Try OpenRouter
  if (openRouterApiKey) {
    try {
      const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${openRouterApiKey}`,
          "Content-Type": "application/json",
          "HTTP-Referer": "com.lumina.antheia"
        },
        body: JSON.stringify({
          model: "meta-llama/llama-3-8b-instruct:free",
          messages,
          max_tokens: max_tokens ?? 300,
        })
      });
      if (response.status === 200) {
        const data = await response.json();
        const content = data.choices[0].message.content;
        return new Response(JSON.stringify({ success: true, provider: "openrouter", content: content }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }
    } catch (e: any) {
      console.warn("OpenRouter failed in Edge Function, trying fallback...", e.message);
    }
  }

  // Try OpenAI
  if (openAiApiKey) {
    try {
      const response = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${openAiApiKey}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          messages,
          temperature: temperature ?? 0.7,
          max_tokens: max_tokens ?? 300,
        })
      });
      if (response.status === 200) {
        const data = await response.json();
        const content = data.choices[0].message.content;
        return new Response(JSON.stringify({ success: true, provider: "openai", content: content }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }
    } catch (e: any) {
      console.warn("OpenAI failed in Edge Function.", e.message);
    }
  }

  return new Response(JSON.stringify({ error: "All AI LLM providers failed or keys not configured." }), {
    status: 502,
    headers: { ...corsHeaders, "Content-Type": "application/json" }
  });
}

// ── Audio Transcription Gateway ──
async function handleTranscribe(payload: any) {
  const deepgramApiKey = Deno.env.get("DEEPGRAM_API_KEY") || "";
  // Get API keys from environment (supports comma-separated list of keys or individual variables)
  const groqKeys = getGroqApiKeys();
  
  const formData = payload.formData as FormData;
  const audioFile = formData.get("file") as File;
  if (!audioFile) {
    return new Response(JSON.stringify({ error: "No audio file provided in form-data" }), { status: 400, headers: corsHeaders });
  }
  
  const fileBytes = new Uint8Array(await audioFile.arrayBuffer());

  // Try Deepgram
  if (deepgramApiKey) {
    try {
      const response = await fetch("https://api.deepgram.com/v1/listen?model=nova-2&punctuate=true", {
        method: "POST",
        headers: {
          "Authorization": `Token ${deepgramApiKey}`,
          "Content-Type": audioFile.type || "audio/m4a"
        },
        body: fileBytes
      });
      if (response.status === 200) {
        const data = await response.json();
        const text = data.results?.channels?.[0]?.alternatives?.[0]?.transcript || "";
        if (text) {
          return new Response(JSON.stringify({ text, provider: "deepgram" }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" }
          });
        }
      }
    } catch (e: any) {
      console.warn("Deepgram failed in Edge Function, trying Whisper...", e.message);
    }
  }

  // Try Groq Whisper keys one by one
  for (const apiKey of groqKeys) {
    try {
      const whisperForm = new FormData();
      whisperForm.append("file", audioFile);
      whisperForm.append("model", "whisper-large-v3");

      const response = await fetch("https://api.groq.com/openai/v1/audio/transcriptions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`
        },
        body: whisperForm
      });
      if (response.status === 200) {
        const data = await response.json();
        const text = data.text || "";
        return new Response(JSON.stringify({ text, provider: "groq-whisper" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      } else {
        const errText = await response.text();
        console.warn(`Whisper key failed, returned status ${response.status}: ${errText}`);
      }
    } catch (e: any) {
      console.error("Groq Whisper transcription failed.", e.message);
    }
  }

  return new Response(JSON.stringify({ error: "All transcription providers failed." }), {
    status: 502,
    headers: { ...corsHeaders, "Content-Type": "application/json" }
  });
}

// ── Hugging Face Emotion Detection Gateway ──
async function handleEmotion(payload: any) {
  const { text } = payload;
  const hfKey = Deno.env.get("HUGGINGFACE_API_KEY") || "";

  try {
    const headers: Record<string, string> = { "Content-Type": "application/json" };
    if (hfKey) {
      headers["Authorization"] = `Bearer ${hfKey}`;
    }

    const response = await fetch("https://api-inference.huggingface.co/models/j-hartmann/emotion-english-distilroberta-base", {
      method: "POST",
      headers,
      body: JSON.stringify({ inputs: text.substring(0, Math.min(text.length, 512)) })
    });

    if (response.status === 200) {
      const raw = await response.json();
      const items = (raw instanceof Array && raw.length > 0 && raw[0] instanceof Array)
          ? raw[0]
          : (raw instanceof Array ? raw : []);

      let topEmotion = "neutral";
      let topScore = 0;
      for (const item of items) {
        const score = Number(item.score || 0);
        if (score > topScore) {
          topScore = score;
          topEmotion = String(item.label || "neutral").toLowerCase();
        }
      }

      return new Response(JSON.stringify({ emotion: topEmotion, score: topScore, provider: "huggingface" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }
  } catch (e: any) {
    console.warn("HuggingFace emotion analysis failed, falling back to neutral.", e.message);
  }

  return new Response(JSON.stringify({ emotion: "neutral", score: 0.5, provider: "fallback" }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" }
  });
}
