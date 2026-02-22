import { Audio } from 'expo-av';
import * as FileSystem from 'expo-file-system';
import type { TranscriptionResult, TranscriptionSegment } from '@/types';

/**
 * Voice recording and transcription service
 *
 * Supports:
 * - Native speech recognition via expo-speech-recognition
 * - On-device Whisper model (requires react-native-executorch in native build)
 */
export class VoiceService {
  private recording: Audio.Recording | null = null;
  private sound: Audio.Sound | null = null;

  /**
   * Request audio permissions
   */
  static async requestPermissions(): Promise<boolean> {
    const { status } = await Audio.requestPermissionsAsync();
    return status === 'granted';
  }

  /**
   * Check if audio permissions are granted
   */
  static async hasPermissions(): Promise<boolean> {
    const { status } = await Audio.getPermissionsAsync();
    return status === 'granted';
  }

  /**
   * Configure audio session for recording
   */
  async prepareForRecording(): Promise<void> {
    await Audio.setAudioModeAsync({
      allowsRecordingIOS: true,
      playsInSilentModeIOS: true,
      staysActiveInBackground: false,
      shouldDuckAndroid: true,
    });
  }

  /**
   * Start recording audio
   */
  async startRecording(): Promise<void> {
    if (this.recording) {
      throw new Error('Recording already in progress');
    }

    await this.prepareForRecording();

    const { recording } = await Audio.Recording.createAsync(
      Audio.RecordingOptionsPresets.HIGH_QUALITY
    );

    this.recording = recording;
  }

  /**
   * Stop recording and return the audio URI
   */
  async stopRecording(): Promise<{ uri: string; duration: number } | null> {
    if (!this.recording) {
      return null;
    }

    try {
      await this.recording.stopAndUnloadAsync();
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: false,
      });

      const uri = this.recording.getURI();
      const status = await this.recording.getStatusAsync();

      this.recording = null;

      if (!uri) return null;

      return {
        uri,
        duration: status.durationMillis || 0,
      };
    } catch (error) {
      console.error('Failed to stop recording:', error);
      this.recording = null;
      return null;
    }
  }

  /**
   * Cancel recording without saving
   */
  async cancelRecording(): Promise<void> {
    if (this.recording) {
      try {
        await this.recording.stopAndUnloadAsync();
      } catch {
        // Ignore errors when canceling
      }
      this.recording = null;
    }
  }

  /**
   * Get current recording status
   */
  async getRecordingStatus(): Promise<Audio.RecordingStatus | null> {
    if (!this.recording) return null;
    return await this.recording.getStatusAsync();
  }

  /**
   * Play audio file
   */
  async playAudio(uri: string): Promise<void> {
    await this.stopPlayback();

    const { sound } = await Audio.Sound.createAsync({ uri });
    this.sound = sound;
    await sound.playAsync();
  }

  /**
   * Stop audio playback
   */
  async stopPlayback(): Promise<void> {
    if (this.sound) {
      await this.sound.stopAsync();
      await this.sound.unloadAsync();
      this.sound = null;
    }
  }

  /**
   * Get audio file info
   */
  async getAudioInfo(uri: string): Promise<{ duration: number; size: number } | null> {
    try {
      const { sound } = await Audio.Sound.createAsync({ uri });
      const status = await sound.getStatusAsync();
      await sound.unloadAsync();

      const fileInfo = await FileSystem.getInfoAsync(uri);
      const size = fileInfo.exists ? (fileInfo as { size: number }).size : 0;

      if (status.isLoaded) {
        return {
          duration: status.durationMillis || 0,
          size,
        };
      }
      return null;
    } catch {
      return null;
    }
  }

  /**
   * Transcribe audio using native speech recognition
   *
   * Note: This is a simplified implementation. Full implementation would use
   * expo-speech-recognition for native APIs or react-native-executorch for Whisper.
   */
  async transcribeNative(uri: string): Promise<TranscriptionResult> {
    // Placeholder for native speech recognition
    // In a full implementation, this would use expo-speech-recognition
    console.log('Native transcription not implemented - requires native build');

    return {
      text: '',
      confidence: 0,
      source: 'native',
      duration: 0,
      segments: [],
    };
  }

  /**
   * Transcribe audio using on-device Whisper model
   *
   * Note: Requires react-native-executorch with Whisper model in native build
   */
  async transcribeWhisper(uri: string): Promise<TranscriptionResult> {
    // Placeholder for Whisper transcription
    // In a full implementation, this would use react-native-executorch
    console.log('Whisper transcription not implemented - requires native build with executorch');

    return {
      text: '',
      confidence: 0,
      source: 'whisper',
      duration: 0,
      segments: [],
    };
  }

  /**
   * Transcribe audio with automatic engine selection
   */
  async transcribe(
    uri: string,
    preferredEngine: 'whisper' | 'native' | 'auto' = 'auto'
  ): Promise<TranscriptionResult> {
    // In a full implementation:
    // - 'whisper' would use on-device Whisper model
    // - 'native' would use platform speech recognition APIs
    // - 'auto' would try Whisper first, fall back to native

    if (preferredEngine === 'whisper' || preferredEngine === 'auto') {
      try {
        const result = await this.transcribeWhisper(uri);
        if (result.text) return result;
      } catch {
        // Fall through to native
      }
    }

    return this.transcribeNative(uri);
  }

  /**
   * Delete an audio file
   */
  async deleteAudioFile(uri: string): Promise<void> {
    try {
      await FileSystem.deleteAsync(uri, { idempotent: true });
    } catch (error) {
      console.error('Failed to delete audio file:', error);
    }
  }

  /**
   * Copy audio to app's document directory
   */
  async saveAudioFile(
    sourceUri: string,
    filename: string
  ): Promise<string> {
    const destDir = `${FileSystem.documentDirectory}audio/`;
    const destUri = `${destDir}${filename}`;

    // Ensure directory exists
    const dirInfo = await FileSystem.getInfoAsync(destDir);
    if (!dirInfo.exists) {
      await FileSystem.makeDirectoryAsync(destDir, { intermediates: true });
    }

    await FileSystem.copyAsync({
      from: sourceUri,
      to: destUri,
    });

    return destUri;
  }
}

export default VoiceService;
