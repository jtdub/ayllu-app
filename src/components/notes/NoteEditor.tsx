import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import type { FieldNote, LocationCoordinates } from '@/types';

interface NoteEditorProps {
  initialNote?: Partial<FieldNote>;
  location?: LocationCoordinates | null;
  defaultTags?: string[];
  onSave: (note: NoteEditorData) => void;
  onCancel: () => void;
  onStartRecording?: () => void;
  isRecording?: boolean;
}

export interface NoteEditorData {
  title: string | null;
  content: string;
  tags: string[];
  latitude: number | null;
  longitude: number | null;
}

/**
 * Rich note editor with title, content, tags, and voice recording
 */
export function NoteEditor({
  initialNote,
  location,
  defaultTags = [],
  onSave,
  onCancel,
  onStartRecording,
  isRecording = false,
}: NoteEditorProps) {
  const [title, setTitle] = useState(initialNote?.title || '');
  const [content, setContent] = useState(initialNote?.content || '');
  const [tags, setTags] = useState<string[]>(initialNote?.tags || defaultTags);
  const [newTag, setNewTag] = useState('');
  const [includeLocation, setIncludeLocation] = useState(true);

  const contentRef = useRef<TextInput>(null);

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
    if (!content.trim()) return;

    onSave({
      title: title.trim() || null,
      content: content.trim(),
      tags,
      latitude: includeLocation && location ? location.latitude : null,
      longitude: includeLocation && location ? location.longitude : null,
    });
  };

  const canSave = content.trim().length > 0;

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <View style={styles.header}>
        <TouchableOpacity onPress={onCancel} style={styles.headerButton}>
          <Ionicons name="close" size={24} color="#888" />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>{initialNote?.id ? 'Edit Note' : 'New Note'}</Text>
        <TouchableOpacity onPress={handleSave} style={styles.headerButton} disabled={!canSave}>
          <Text style={[styles.saveText, !canSave && styles.saveTextDisabled]}>Save</Text>
        </TouchableOpacity>
      </View>

      <ScrollView style={styles.content} keyboardShouldPersistTaps="handled">
        {/* Title */}
        <TextInput
          style={styles.titleInput}
          value={title}
          onChangeText={setTitle}
          placeholder="Title (optional)"
          placeholderTextColor="#666"
          returnKeyType="next"
          onSubmitEditing={() => contentRef.current?.focus()}
        />

        {/* Content */}
        <TextInput
          ref={contentRef}
          style={styles.contentInput}
          value={content}
          onChangeText={setContent}
          placeholder="Write your field notes..."
          placeholderTextColor="#666"
          multiline
          textAlignVertical="top"
        />

        {/* Voice recording button */}
        {onStartRecording && (
          <TouchableOpacity
            style={[styles.voiceButton, isRecording && styles.voiceButtonActive]}
            onPress={onStartRecording}
          >
            <Ionicons
              name={isRecording ? 'radio-button-on' : 'mic'}
              size={20}
              color={isRecording ? '#ff6b6b' : '#4a9eff'}
            />
            <Text style={[styles.voiceButtonText, isRecording && styles.voiceButtonTextActive]}>
              {isRecording ? 'Recording...' : 'Add Voice Note'}
            </Text>
          </TouchableOpacity>
        )}

        {/* Location toggle */}
        {location && (
          <TouchableOpacity
            style={styles.locationRow}
            onPress={() => setIncludeLocation(!includeLocation)}
          >
            <View style={styles.locationInfo}>
              <Ionicons
                name={includeLocation ? 'location' : 'location-outline'}
                size={18}
                color={includeLocation ? '#4a9eff' : '#666'}
              />
              <Text style={styles.locationText}>
                {includeLocation
                  ? `${location.latitude.toFixed(6)}, ${location.longitude.toFixed(6)}`
                  : 'Location disabled'}
              </Text>
            </View>
            <View style={[styles.checkbox, includeLocation && styles.checkboxChecked]}>
              {includeLocation && <Ionicons name="checkmark" size={14} color="#fff" />}
            </View>
          </TouchableOpacity>
        )}

        {/* Tags */}
        <View style={styles.tagsSection}>
          <Text style={styles.sectionLabel}>Tags</Text>
          <View style={styles.tagsContainer}>
            {tags.map((tag) => (
              <TouchableOpacity key={tag} style={styles.tag} onPress={() => handleRemoveTag(tag)}>
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
              <Ionicons name="add" size={20} color={newTag.trim() ? '#4a9eff' : '#666'} />
            </TouchableOpacity>
          </View>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f0f1a',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 16,
    backgroundColor: '#1a1a2e',
    borderBottomWidth: 1,
    borderBottomColor: '#2a2a4e',
  },
  headerButton: {
    padding: 4,
    minWidth: 50,
  },
  headerTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: '#fff',
  },
  saveText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#4a9eff',
    textAlign: 'right',
  },
  saveTextDisabled: {
    color: '#666',
  },
  content: {
    flex: 1,
    padding: 16,
  },
  titleInput: {
    fontSize: 20,
    fontWeight: '600',
    color: '#fff',
    paddingVertical: 8,
    marginBottom: 8,
  },
  contentInput: {
    fontSize: 16,
    color: '#ddd',
    lineHeight: 24,
    minHeight: 150,
    paddingVertical: 8,
  },
  voiceButton: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    backgroundColor: '#1a1a2e',
    borderRadius: 8,
    marginVertical: 16,
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  voiceButtonActive: {
    borderColor: '#ff6b6b',
    backgroundColor: '#2a1a1a',
  },
  voiceButtonText: {
    fontSize: 15,
    color: '#4a9eff',
    marginLeft: 8,
  },
  voiceButtonTextActive: {
    color: '#ff6b6b',
  },
  locationRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 12,
    backgroundColor: '#1a1a2e',
    borderRadius: 8,
    marginBottom: 16,
  },
  locationInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  locationText: {
    fontSize: 14,
    color: '#aaa',
    marginLeft: 8,
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
  },
  checkbox: {
    width: 22,
    height: 22,
    borderRadius: 4,
    borderWidth: 2,
    borderColor: '#2a2a4e',
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkboxChecked: {
    backgroundColor: '#4a9eff',
    borderColor: '#4a9eff',
  },
  tagsSection: {
    marginTop: 8,
  },
  sectionLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: '#888',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 8,
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
});

export default NoteEditor;
