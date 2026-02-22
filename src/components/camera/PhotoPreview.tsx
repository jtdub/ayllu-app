import React, { useState } from 'react';
import {
  View,
  Text,
  Image,
  TouchableOpacity,
  StyleSheet,
  TextInput,
  ScrollView,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import type { CapturedPhoto } from './CameraView';
import { formatCoordinates } from '@/utils';

interface PhotoPreviewProps {
  photo: CapturedPhoto;
  onSave: (data: PhotoSaveData) => void;
  onRetake: () => void;
  onDiscard: () => void;
  defaultTags?: string[];
}

export interface PhotoSaveData {
  uri: string;
  width: number;
  height: number;
  latitude: number | null;
  longitude: number | null;
  altitude: number | null;
  caption: string;
  tags: string[];
  timestamp: string;
}

/**
 * Preview component for captured photos with caption and tag editing
 */
export function PhotoPreview({
  photo,
  onSave,
  onRetake,
  onDiscard,
  defaultTags = [],
}: PhotoPreviewProps) {
  const [caption, setCaption] = useState('');
  const [tags, setTags] = useState<string[]>(defaultTags);
  const [newTag, setNewTag] = useState('');

  const handleAddTag = () => {
    const tag = newTag.trim().toLowerCase();
    if (tag && !tags.includes(tag)) {
      setTags([...tags, tag]);
      setNewTag('');
    }
  };

  const handleRemoveTag = (tagToRemove: string) => {
    setTags(tags.filter((t) => t !== tagToRemove));
  };

  const handleSave = () => {
    onSave({
      uri: photo.uri,
      width: photo.width,
      height: photo.height,
      latitude: photo.latitude,
      longitude: photo.longitude,
      altitude: photo.altitude,
      caption: caption.trim(),
      tags,
      timestamp: photo.timestamp,
    });
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView style={styles.scrollView} contentContainerStyle={styles.content}>
        {/* Photo preview */}
        <View style={styles.imageContainer}>
          {photo.uri ? (
            <Image source={{ uri: photo.uri }} style={styles.image} resizeMode="contain" />
          ) : (
            <View style={styles.imagePlaceholder}>
              <Ionicons name="image" size={64} color="#444" />
              <Text style={styles.imagePlaceholderText}>Photo Preview</Text>
            </View>
          )}
        </View>

        {/* Location info */}
        {photo.latitude !== null && photo.longitude !== null && (
          <View style={styles.locationCard}>
            <Ionicons name="location" size={18} color="#4a9eff" />
            <Text style={styles.locationText}>
              {formatCoordinates(photo.latitude, photo.longitude)}
            </Text>
            {photo.altitude !== null && (
              <Text style={styles.altitudeText}>
                Alt: {photo.altitude.toFixed(1)}m
              </Text>
            )}
          </View>
        )}

        {/* Caption input */}
        <View style={styles.inputGroup}>
          <Text style={styles.label}>Caption</Text>
          <TextInput
            style={styles.captionInput}
            value={caption}
            onChangeText={setCaption}
            placeholder="Describe this photo..."
            placeholderTextColor="#666"
            multiline
            maxLength={500}
          />
        </View>

        {/* Tags */}
        <View style={styles.inputGroup}>
          <Text style={styles.label}>Tags</Text>
          <View style={styles.tagsContainer}>
            {tags.map((tag) => (
              <TouchableOpacity
                key={tag}
                style={styles.tag}
                onPress={() => handleRemoveTag(tag)}
              >
                <Text style={styles.tagText}>{tag}</Text>
                <Ionicons name="close" size={14} color="#888" />
              </TouchableOpacity>
            ))}
          </View>
          <View style={styles.tagInputRow}>
            <TextInput
              style={styles.tagInput}
              value={newTag}
              onChangeText={setNewTag}
              placeholder="Add tag..."
              placeholderTextColor="#666"
              onSubmitEditing={handleAddTag}
              returnKeyType="done"
            />
            <TouchableOpacity
              style={styles.addTagButton}
              onPress={handleAddTag}
              disabled={!newTag.trim()}
            >
              <Ionicons
                name="add"
                size={20}
                color={newTag.trim() ? '#4a9eff' : '#666'}
              />
            </TouchableOpacity>
          </View>
        </View>
      </ScrollView>

      {/* Action buttons */}
      <View style={styles.actions}>
        <TouchableOpacity style={styles.secondaryButton} onPress={onDiscard}>
          <Ionicons name="trash" size={20} color="#ff6b6b" />
          <Text style={[styles.buttonText, styles.discardText]}>Discard</Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.secondaryButton} onPress={onRetake}>
          <Ionicons name="camera" size={20} color="#888" />
          <Text style={styles.buttonText}>Retake</Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.primaryButton} onPress={handleSave}>
          <Ionicons name="checkmark" size={20} color="#fff" />
          <Text style={[styles.buttonText, styles.saveText]}>Save</Text>
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f0f1a',
  },
  scrollView: {
    flex: 1,
  },
  content: {
    padding: 16,
    paddingBottom: 100,
  },
  imageContainer: {
    aspectRatio: 4 / 3,
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    overflow: 'hidden',
    marginBottom: 16,
  },
  image: {
    width: '100%',
    height: '100%',
  },
  imagePlaceholder: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  imagePlaceholderText: {
    fontSize: 14,
    color: '#666',
    marginTop: 8,
  },
  locationCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1a1a2e',
    borderRadius: 8,
    padding: 12,
    marginBottom: 16,
  },
  locationText: {
    fontSize: 14,
    color: '#fff',
    marginLeft: 8,
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
  },
  altitudeText: {
    fontSize: 12,
    color: '#888',
    marginLeft: 'auto',
  },
  inputGroup: {
    marginBottom: 20,
  },
  label: {
    fontSize: 13,
    fontWeight: '600',
    color: '#888',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 8,
  },
  captionInput: {
    backgroundColor: '#1a1a2e',
    borderRadius: 8,
    padding: 12,
    color: '#fff',
    fontSize: 15,
    minHeight: 80,
    textAlignVertical: 'top',
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  tagsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginBottom: 8,
  },
  tag: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#2a2a4e',
    borderRadius: 6,
    paddingHorizontal: 10,
    paddingVertical: 6,
    marginRight: 8,
    marginBottom: 8,
  },
  tagText: {
    fontSize: 13,
    color: '#aaa',
    marginRight: 6,
  },
  tagInputRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  tagInput: {
    flex: 1,
    backgroundColor: '#1a1a2e',
    borderRadius: 8,
    padding: 12,
    color: '#fff',
    fontSize: 15,
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  addTagButton: {
    width: 44,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: 8,
  },
  actions: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    padding: 16,
    backgroundColor: '#1a1a2e',
    borderTopWidth: 1,
    borderTopColor: '#2a2a4e',
  },
  secondaryButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  primaryButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#4a9eff',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  buttonText: {
    fontSize: 15,
    color: '#888',
    marginLeft: 8,
  },
  discardText: {
    color: '#ff6b6b',
  },
  saveText: {
    color: '#fff',
    fontWeight: '600',
  },
});

export default PhotoPreview;
