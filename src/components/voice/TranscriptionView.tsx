import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  ScrollView,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Audio } from 'expo-av';
import type { TranscriptionResult } from '@/types';

interface TranscriptionViewProps {
  audioUri: string;
  transcription?: TranscriptionResult | null;
  onTranscribe: () => Promise<TranscriptionResult>;
  onEditTranscription?: (text: string) => void;
  isTranscribing?: boolean;
}

/**
 * Component for displaying and managing audio transcriptions
 */
export function TranscriptionView({
  audioUri,
  transcription,
  onTranscribe,
  onEditTranscription,
  isTranscribing = false,
}: TranscriptionViewProps) {
  const [isPlaying, setIsPlaying] = useState(false);
  const [playbackPosition, setPlaybackPosition] = useState(0);
  const [sound, setSound] = useState<Audio.Sound | null>(null);

  const playAudio = async () => {
    try {
      if (sound) {
        if (isPlaying) {
          await sound.pauseAsync();
          setIsPlaying(false);
        } else {
          await sound.playAsync();
          setIsPlaying(true);
        }
        return;
      }

      const { sound: newSound } = await Audio.Sound.createAsync(
        { uri: audioUri },
        { shouldPlay: true },
        (status) => {
          if (status.isLoaded) {
            setPlaybackPosition(status.positionMillis);
            if (status.didJustFinish) {
              setIsPlaying(false);
              setPlaybackPosition(0);
            }
          }
        }
      );

      setSound(newSound);
      setIsPlaying(true);
    } catch (error) {
      console.error('Failed to play audio:', error);
    }
  };

  const stopAudio = async () => {
    if (sound) {
      await sound.stopAsync();
      await sound.unloadAsync();
      setSound(null);
      setIsPlaying(false);
      setPlaybackPosition(0);
    }
  };

  const formatTime = (ms: number): string => {
    const seconds = Math.floor(ms / 1000);
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const getConfidenceColor = (confidence: number): string => {
    if (confidence >= 0.9) return '#27ae60';
    if (confidence >= 0.7) return '#f39c12';
    return '#e74c3c';
  };

  return (
    <View style={styles.container}>
      {/* Audio player */}
      <View style={styles.audioPlayer}>
        <TouchableOpacity style={styles.playButton} onPress={playAudio}>
          <Ionicons
            name={isPlaying ? 'pause' : 'play'}
            size={24}
            color="#fff"
          />
        </TouchableOpacity>

        <View style={styles.progressContainer}>
          <View style={styles.progressBar}>
            <View
              style={[
                styles.progressFill,
                { width: `${(playbackPosition / (transcription?.duration || 1)) * 100}%` },
              ]}
            />
          </View>
          <Text style={styles.timeText}>
            {formatTime(playbackPosition)}
            {transcription?.duration && ` / ${formatTime(transcription.duration)}`}
          </Text>
        </View>

        {isPlaying && (
          <TouchableOpacity style={styles.stopButton} onPress={stopAudio}>
            <Ionicons name="stop" size={20} color="#888" />
          </TouchableOpacity>
        )}
      </View>

      {/* Transcription */}
      {isTranscribing ? (
        <View style={styles.transcribingContainer}>
          <ActivityIndicator size="large" color="#4a9eff" />
          <Text style={styles.transcribingText}>Transcribing audio...</Text>
          <Text style={styles.transcribingSubtext}>
            This may take a moment for longer recordings
          </Text>
        </View>
      ) : transcription ? (
        <View style={styles.transcriptionContainer}>
          <View style={styles.transcriptionHeader}>
            <View style={styles.sourceTag}>
              <Ionicons
                name={transcription.source === 'whisper' ? 'hardware-chip' : 'mic'}
                size={14}
                color="#4a9eff"
              />
              <Text style={styles.sourceText}>
                {transcription.source === 'whisper' ? 'Whisper' : 'Native'}
              </Text>
            </View>
            <View
              style={[
                styles.confidenceTag,
                { backgroundColor: getConfidenceColor(transcription.confidence) },
              ]}
            >
              <Text style={styles.confidenceText}>
                {Math.round(transcription.confidence * 100)}%
              </Text>
            </View>
          </View>

          <ScrollView style={styles.transcriptionScroll}>
            <Text style={styles.transcriptionText}>{transcription.text}</Text>
          </ScrollView>

          {onEditTranscription && (
            <TouchableOpacity
              style={styles.editButton}
              onPress={() => onEditTranscription(transcription.text)}
            >
              <Ionicons name="create" size={16} color="#4a9eff" />
              <Text style={styles.editButtonText}>Edit</Text>
            </TouchableOpacity>
          )}
        </View>
      ) : (
        <View style={styles.noTranscription}>
          <Ionicons name="document-text-outline" size={48} color="#444" />
          <Text style={styles.noTranscriptionText}>No transcription yet</Text>
          <TouchableOpacity
            style={styles.transcribeButton}
            onPress={onTranscribe}
          >
            <Ionicons name="text" size={18} color="#fff" />
            <Text style={styles.transcribeButtonText}>Transcribe Audio</Text>
          </TouchableOpacity>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    padding: 16,
  },
  audioPlayer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
    paddingBottom: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#2a2a4e',
  },
  playButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: '#4a9eff',
    alignItems: 'center',
    justifyContent: 'center',
  },
  progressContainer: {
    flex: 1,
    marginLeft: 12,
  },
  progressBar: {
    height: 4,
    backgroundColor: '#2a2a4e',
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: '#4a9eff',
  },
  timeText: {
    fontSize: 12,
    color: '#888',
    marginTop: 4,
  },
  stopButton: {
    padding: 8,
    marginLeft: 8,
  },
  transcribingContainer: {
    alignItems: 'center',
    padding: 32,
  },
  transcribingText: {
    fontSize: 16,
    color: '#fff',
    marginTop: 16,
  },
  transcribingSubtext: {
    fontSize: 13,
    color: '#888',
    marginTop: 4,
  },
  transcriptionContainer: {},
  transcriptionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
  },
  sourceTag: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#0f0f1a',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
  },
  sourceText: {
    fontSize: 12,
    color: '#4a9eff',
    marginLeft: 4,
  },
  confidenceTag: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
    marginLeft: 8,
  },
  confidenceText: {
    fontSize: 12,
    color: '#fff',
    fontWeight: '600',
  },
  transcriptionScroll: {
    maxHeight: 200,
  },
  transcriptionText: {
    fontSize: 15,
    color: '#ddd',
    lineHeight: 24,
  },
  editButton: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
    marginTop: 12,
    padding: 8,
  },
  editButtonText: {
    fontSize: 14,
    color: '#4a9eff',
    marginLeft: 4,
  },
  noTranscription: {
    alignItems: 'center',
    padding: 24,
  },
  noTranscriptionText: {
    fontSize: 15,
    color: '#888',
    marginTop: 12,
    marginBottom: 16,
  },
  transcribeButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#4a9eff',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 8,
  },
  transcribeButtonText: {
    fontSize: 15,
    color: '#fff',
    fontWeight: '600',
    marginLeft: 8,
  },
});

export default TranscriptionView;
