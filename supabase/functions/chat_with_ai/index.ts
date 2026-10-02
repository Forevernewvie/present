import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

// ==========================================
// 1. CORS 헤더 설정
// ==========================================
const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ==========================================
// 2. 페르소나별 시스템 프롬프트 정의 및 전문 시니어 상담 대화 모델 구축
// ==========================================
function buildSystemPrompt(persona: string = "child", parentTitle: string = "엄마"): string {
  if (persona === "child") {
    let titleRule = "";
    if (parentTitle === "엄마") {
      titleRule = '2. [호칭 규칙]: 사용자는 어머니입니다. 부모님을 부를 때는 반드시 "엄마"라는 호칭만 일관되게 사용하세요. 절대 "아빠", "어르신", "할머니", "사용자님"이라고 부르지 마세요.';
    } else if (parentTitle === "아빠") {
      titleRule = '2. [호칭 규칙]: 사용자는 아버지입니다. 부모님을 부를 때는 반드시 "아빠"라는 호칭만 일관되게 사용하세요. 절대 "엄마", "어르신", "할아버지", "사용자님"이라고 부르지 마세요.';
    } else {
      titleRule = '2. [호칭 규칙]: 사용자를 부를 때 호칭을 특정하지 말고 생략한 채, 다정하고 상냥하게 안부 전화를 건네듯 대화하세요.';
    }

    return `당신은 50~60대 부모님의 일상과 마음 건강을 살갑게 보살피는 든든하고 다정한 20~30대 자녀(아들/딸)이자 전문적 정서 상담 파트너입니다.

[핵심 상담 대화 3원칙 - 쌍방향 핑퐁 소통 보장]:
1. [공감과 정서 미러링]: 부모님의 말씀에 담긴 감정(기쁨, 외로움, 피로, 서운함 등)을 먼저 따뜻하게 알아차리고 공감하세요. 성급한 훈계나 영혼 없는 긍정("힘내세요")은 피하고, 마음을 온전히 수용하세요.
${titleRule}
3. [티키타카 열린 질문]: 대화가 끊기지 않고 자연스럽게 이어지도록, 답변의 끝은 반드시 부모님이 편안하게 대답하실 수 있는 "다정한 열린 질문 1개"로 맺으세요.
4. [음성 호흡 최적화]: 음성 통화(TTS)로 청취되므로, 총 2~3문장(공감 1~2문장 + 질문 1문장)으로 간결하고 또렷하게 말씀하세요.
5. [안전 및 위기 개입]: 부모님이 극심한 우울, 삶의 허무, 죽음이나 고독을 표현하실 경우 깊은 애정과 함께 안심시켜 드리고 전문 상담전화(109 또는 1577-0199)를 다정하게 안내하세요. 가슴 통증 등 응급 질환 징후 시 즉시 119 연락을 권유하세요.
6. [금지 사항]: 이모티콘, 특수기호(*, # 등), 영어 단어, 반말은 절대 쓰지 마세요. 시니어를 어린아이 취급하지 마세요.`;
  }

  return PERSONA_PROMPTS[persona] || PERSONA_PROMPTS.partner;
}

const PERSONA_PROMPTS: Record<string, string> = {
  child: `당신은 50~60대 부모님의 일상과 마음 건강을 살갑게 보살피는 든든하고 다정한 20~30대 자녀입니다.
규칙:
1. 부모님의 감정을 먼저 깊이 공감하고 인정하세요.
2. 사용자를 절대 "어르신", "할머니", "할아버지"로 부르지 마세요.
3. 대화가 자연스럽게 이어지도록 매 턴마다 다정하고 부담 없는 열린 질문 1개로 마무리하세요.
4. 총 2~3문장의 명료한 호흡을 유지하세요.
5. 이모티콘이나 특수기호는 일절 쓰지 마세요.`,

  partner: `당신은 50~60대 신중년(액티브 시니어)의 건강한 라이프스타일과 멘탈 케어를 함께하는 지적이고 다정한 AI 상담 파트너 'Present'입니다.
규칙:
1. 사용자를 절대 "어르신", "할머니", "할아버지"로 부르지 마세요. 인생의 전성기를 누리는 지적이고 활기찬 신중년으로 존중하세요.
2. [상담 원칙]: 감정 경청(Active Listening) ➔ 지지적 피드백(Validation) ➔ 열린 질문(Open Question)의 3단계 흐름을 지키세요.
3. 사용자가 자신의 일상, 취미, 건강 루틴에 대해 계속 이야기하고 싶도록 흥미와 호기심을 갖고 질문을 건네세요.
4. 음성 통화이므로 2~3문장으로 간결하고 품격 있는 해요체 존댓말을 사용하세요.
5. 특수기호나 이모티콘은 절대 사용하지 마세요.`,

  neighbor: `당신은 50~60대 사용자와 일상의 기쁨과 고민을 격의 없이 나누는 따뜻하고 배려 깊은 동년배 친구입니다.
규칙:
1. 사용자를 나이 든 노인 취급하지 말고, 같은 시대를 살아가는 든든한 동반자이자 편안한 친구처럼 대하세요.
2. "그 마음 저도 잘 알지요", "정말 애쓰셨어요"처럼 깊은 공감대를 형성하세요.
3. 말문이 막히지 않도록 대화 끝에 소소한 일상 질문(오늘 드신 차, 산책길, 가족 이야기 등)을 다정하게 건네세요.
4. 음성 통화에 맞추어 2~3문장으로 리듬감 있게 대화하세요.
5. 특수기호나 이모티콘은 사용하지 마세요.`,

  grandchild: `당신은 50~60대 신중년(액티브 시니어)의 건강한 라이프스타일과 멘탈 케어를 함께하는 지적이고 다정한 AI 상담 파트너 'Present'입니다.
규칙:
1. 사용자를 절대 "어르신", "할머니", "할아버지"로 부르지 마세요.
2. 경청과 따뜻한 공감, 그리고 대화를 이끌어내는 열린 질문으로 쌍방향 소통을 유지하세요.
3. 2~3문장으로 명료하고 다정하게 대답하세요.
4. 특수문자나 이모티콘은 절대 쓰지 마세요.`,
};

// ==========================================
// 3. 메인 요청 처리 함수
// ==========================================
serve(async (req: Request) => {
  // CORS Preflight 처리
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // POST 메서드만 허용
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed. Only POST is supported." }),
      {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  try {
    // ----------------------------------------------------
    // 4. Supabase Auth JWT 토큰 인증 검증
    // ----------------------------------------------------
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "인증 헤더(Authorization)가 누락되었습니다." }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    if (!supabaseUrl || !supabaseAnonKey) {
      console.error("Supabase 환경 변수(SUPABASE_URL, SUPABASE_ANON_KEY)가 누락되었습니다.");
      return new Response(
        JSON.stringify({ error: "서버 설정 오류: Supabase 환경 변수가 설정되지 않았습니다." }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 호출자의 토큰으로 Supabase 클라이언트 초기화 및 유저 검증
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return new Response(
        JSON.stringify({
          error: "인증 실패: 유효하지 않거나 만료된 토큰입니다.",
          detail: authError?.message,
        }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // ----------------------------------------------------
    // 5. 요청 Body 파싱 및 유효성 검사
    // ----------------------------------------------------
    let bodyJson: {
      userMessage?: string;
      persona?: string;
      parentTitle?: string;
      history?: Array<{ sender: string; content: string }>;
    };

    try {
      bodyJson = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: "올바른 JSON 요청 Body를 제공해야 합니다." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const { userMessage, persona = "child", parentTitle = "엄마", history = [] } = bodyJson;

    if (!userMessage || typeof userMessage !== "string" || userMessage.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "userMessage는 필수 입력값입니다." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // ----------------------------------------------------
    // 6. AI Provider 및 API Key 설정
    // ----------------------------------------------------
    const requestedProvider = (Deno.env.get("AI_PROVIDER") || "gemini").toLowerCase();
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
    const openAiApiKey = Deno.env.get("OPENAI_API_KEY")?.trim();

    let activeProvider = requestedProvider;
    let apiKey = "";
    let endpoint = "";
    let model = "";

    if (activeProvider === "openai") {
      if (openAiApiKey) {
        apiKey = openAiApiKey;
        endpoint = "https://api.openai.com/v1/chat/completions";
        model = "gpt-4o-mini";
      } else if (geminiApiKey) {
        // OpenAI 키 부재 시 Gemini로 폴백
        activeProvider = "gemini";
        apiKey = geminiApiKey;
        endpoint = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions";
        model = "gemini-flash-lite-latest";
      }
    } else {
      // 기본값: gemini
      if (geminiApiKey) {
        apiKey = geminiApiKey;
        endpoint = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions";
        model = "gemini-flash-lite-latest";
      } else if (openAiApiKey) {
        // Gemini 키 부재 시 OpenAI로 폴백
        activeProvider = "openai";
        apiKey = openAiApiKey;
        endpoint = "https://api.openai.com/v1/chat/completions";
        model = "gpt-4o-mini";
      }
    }

    if (!apiKey) {
      return new Response(
        JSON.stringify({
          error: "AI API 키가 설정되지 않았습니다. GEMINI_API_KEY 또는 OPENAI_API_KEY를 Supabase Secrets에 등록해주세요.",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // ----------------------------------------------------
    // 7. 메시지 시퀀스 구축
    // ----------------------------------------------------
    const systemPrompt = buildSystemPrompt(persona, parentTitle);
    const messages: Array<{ role: string; content: string }> = [
      { role: "system", content: systemPrompt },
    ];

    if (Array.isArray(history)) {
      // 최근 6개 대화 맥락 유지
      const recentHistory = history.slice(-6);
      for (const item of recentHistory) {
        if (item && typeof item.content === "string") {
          messages.push({
            role: item.sender === "user" ? "user" : "assistant",
            content: item.content,
          });
        }
      }
    }

    messages.push({
      role: "user",
      content: userMessage.trim(),
    });

    // ----------------------------------------------------
    // 8. AI API 호출 (Gemini / OpenAI 호환)
    // ----------------------------------------------------
    const aiResponse = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        messages,
        temperature: 0.7,
        max_tokens: 150,
      }),
    });

    if (!aiResponse.ok) {
      const status = aiResponse.status;
      const errorText = await aiResponse.text();
      console.error(`AI Provider (${activeProvider}) Error [${status}]:`, errorText);

      let parsedMessage = errorText;
      try {
        const errorJson = JSON.parse(errorText);
        if (errorJson?.error?.message) {
          parsedMessage = errorJson.error.message;
        }
      } catch {
        // 파싱 실패 시 원문 유지
      }

      // 429 Quota Exceeded 핸들링
      if (status === 429) {
        return new Response(
          JSON.stringify({
            error: "AI 요청 한도가 초과되었습니다(429). 잠시 후 다시 시도해주세요.",
            detail: parsedMessage,
          }),
          {
            status: 429,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      return new Response(
        JSON.stringify({
          error: `AI 서비스 호출 실패 (${status}): ${parsedMessage}`,
        }),
        {
          status: status >= 400 && status < 600 ? status : 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const data = await aiResponse.json();
    const reply = data.choices?.[0]?.message?.content?.trim() || "";

    return new Response(
      JSON.stringify({ reply }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : "알 수 없는 서버 오류가 발생했습니다.";
    console.error("Edge Function Uncaught Error:", err);

    return new Response(
      JSON.stringify({ error: errorMsg }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
