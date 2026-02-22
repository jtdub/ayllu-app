import { useState, useCallback, useRef, useEffect } from 'react';
import { VoiceService } from '@/services/voice';
import type { TranscriptionResult } from '@/types';

interface UseVoiceReturn {
  isRecording: boolean;
  isPaused: boolean;
  duration: number;
  hasPermission: boolean | null;
  error: string | null;
  startRecording: () => Promise<void>;
  stopRecording: () => Promise<RecordingResult | null>;
  cancelRecording: () => Promise<void>;
  pauseRecording: () => Promise<void>;
  resumeRecording: () => Promise<void>;
  transcribe: (uri: string, engine?: 'whisper' | 'native' | 'auto') => Promise<TranscriptionResult>;
  playAudio: (uri: string) => Promise<void>;
  stopPlayback: () => Promise<void>;
  requestPermission: () => Promise<boolean>;
}

interface RecordingResult {
  uri: string;
  duration: number;
  filename: string;
}

/**
 * Hook for voice recording and transcription
 */
export function useVoice(): UseVoiceReturn {
  const [isRecording, setIsRecording] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [duration, setDuration] = useState(0);
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const [error, setError] = useState<string | null>(null);

  const serviceRef = useRef<VoiceService | null>(null);
  const timerRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    serviceRef.current = new VoiceService();
    checkPermission();

    return () => {
      if (timerRef.current) {
        clearInterval(timerRef.current);
      }
      serviceRef.current?.cancelRecording();
    };
  }, []);

  const checkPermission = async () => {
    const granted = await VoiceService.hasPermissions();
    setHasPermission(granted);
  };

  const requestPermission = useCallback(async () => {
    const granted = await VoiceService.requestPermissions();
    setHasPermission(granted);
    return granted;
  }, []);

  const startRecording = useCallback(async () => {
    if (!serviceRef.current || isRecording) return;

    if (!hasPermission) {
      const granted = await requestPermission();
      if (!granted) {
        setError('Microphone permission required');
        return;
      }
    }

    try {
      await serviceRef.current.startRecording();
      setIsRecording(true);
      setIsPaused(false);
      setDuration(0);
      setError(null);

      timerRef.current = setInterval(() => {
        setDuration((prev) => prev + 100);
      }, 100);
    } catch (err) {
      setError('Failed to start recording');
      console.error('Start recording error:', err);
    }
  }, [isRecording, hasPermission, requestPermission]);

  const stopRecording = useCallback(async (): Promise<RecordingResult | null> => {
    if (!serviceRef.current || !isRecording) return null;

    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }

    try {
      const result = await serviceRef.current.stopRecording();
      setIsRecording(false);
      setIsPaused(false);

      if (result) {
        const filename = `recording_${Date.now()}.m4a`;
        const savedUri = await serviceRef.current.saveAudioFile(result.uri, filename);

        return {
          uri: savedUri,
          duration: result.duration,
          filename,
        };
      }

      return null;
    } catch (err) {
      setError('Failed to stop recording');
      console.error('Stop recording error:', err);
      return null;
    }
  }, [isRecording]);

  const cancelRecording = useCallback(async () => {
    if (!serviceRef.current) return;

    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }

    await serviceRef.current.cancelRecording();
    setIsRecording(false);
    setIsPaused(false);
    setDuration(0);
  }, []);

  const pauseRecording = useCallback(async () => {
    if (!isRecording || isPaused) return;

    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }

    setIsPaused(true);
  }, [isRecording, isPaused]);

  const resumeRecording = useCallback(async () => {
    if (!isRecording || !isPaused) return;

    timerRef.current = setInterval(() => {
      setDuration((prev) => prev + 100);
    }, 100);

    setIsPaused(false);
  }, [isRecording, isPaused]);

  const transcribe = useCallback(
    async (
      uri: string,
      engine: 'whisper' | 'native' | 'auto' = 'auto'
    ): Promise<TranscriptionResult> => {
      if (!serviceRef.current) {
        return {
          text: '',
          confidence: 0,
          source: 'native',
          duration: 0,
        };
      }

      return serviceRef.current.transcribe(uri, engine);
    },
    []
  );

  const playAudio = useCallback(async (uri: string) => {
    if (!serviceRef.current) return;
    await serviceRef.current.playAudio(uri);
  }, []);

  const stopPlayback = useCallback(async () => {
    if (!serviceRef.current) return;
    await serviceRef.current.stopPlayback();
  }, []);

  return {
    isRecording,
    isPaused,
    duration,
    hasPermission,
    error,
    startRecording,
    stopRecording,
    cancelRecording,
    pauseRecording,
    resumeRecording,
    transcribe,
    playAudio,
    stopPlayback,
    requestPermission,
  };
}

export default useVoice;
