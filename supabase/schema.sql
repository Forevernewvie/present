-- Create users table
CREATE TABLE public.users (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  kakao_id text UNIQUE,
  line_id text UNIQUE,
  name text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  PRIMARY KEY (id)
);

-- Create conversations table (Groups messages by day/session)
CREATE TABLE public.conversations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  session_date date NOT NULL DEFAULT current_date,
  summary text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  PRIMARY KEY (id)
);

-- Create messages table
CREATE TABLE public.messages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender text NOT NULL CHECK (sender IN ('user', 'ai')),
  content text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  PRIMARY KEY (id)
);

-- Create indexes for faster queries
CREATE INDEX idx_conversations_user_id ON public.conversations(user_id);
CREATE INDEX idx_conversations_date ON public.conversations(session_date);
CREATE INDEX idx_messages_conversation_id ON public.messages(conversation_id);
