import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import type { FieldNote } from '@/types';
import { formatDate } from '@/utils';

interface NoteCardProps {
  note: FieldNote;
  onPress?: () => void;
  onLongPress?: () => void;
  showProject?: boolean;
  projectName?: string;
}

/**
 * Card component for displaying field note summary
 */
export function NoteCard({
  note,
  onPress,
  onLongPress,
  showProject = false,
  projectName,
}: NoteCardProps) {
  const hasAudio = note.audioUri !== null;
  const hasLocation = note.latitude !== null && note.longitude !== null;
  const isTranscribed = note.transcriptionSource !== null;

  return (
    <TouchableOpacity
      style={styles.card}
      onPress={onPress}
      onLongPress={onLongPress}
      activeOpacity={onPress ? 0.7 : 1}
    >
      {/* Header */}
      <View style={styles.header}>
        {note.title ? (
          <Text style={styles.title} numberOfLines={1}>
            {note.title}
          </Text>
        ) : (
          <Text style={styles.untitled}>Untitled Note</Text>
        )}
        {hasAudio && (
          <View style={styles.audioIndicator}>
            <Ionicons name="mic" size={14} color="#4a9eff" />
          </View>
        )}
      </View>

      {/* Content preview */}
      <Text style={styles.content} numberOfLines={3}>
        {note.content}
      </Text>

      {/* Tags */}
      {note.tags.length > 0 && (
        <View style={styles.tagsRow}>
          {note.tags.slice(0, 3).map((tag) => (
            <View key={tag} style={styles.tag}>
              <Text style={styles.tagText}>{tag}</Text>
            </View>
          ))}
          {note.tags.length > 3 && <Text style={styles.moreTags}>+{note.tags.length - 3}</Text>}
        </View>
      )}

      {/* Footer */}
      <View style={styles.footer}>
        <View style={styles.metadata}>
          {hasLocation && (
            <View style={styles.metaItem}>
              <Ionicons name="location" size={12} color="#4a9eff" />
            </View>
          )}
          {isTranscribed && (
            <View style={styles.metaItem}>
              <Ionicons name="text" size={12} color="#27ae60" />
              <Text style={styles.metaText}>
                {Math.round((note.transcriptionConfidence || 0) * 100)}%
              </Text>
            </View>
          )}
          {note.waypointId && (
            <View style={styles.metaItem}>
              <Ionicons name="flag" size={12} color="#888" />
            </View>
          )}
          {note.photoId && (
            <View style={styles.metaItem}>
              <Ionicons name="image" size={12} color="#888" />
            </View>
          )}
        </View>

        <View style={styles.dateContainer}>
          {showProject && projectName && <Text style={styles.projectName}>{projectName}</Text>}
          <Text style={styles.date}>{formatDate(note.timestamp, true)}</Text>
        </View>
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  title: {
    fontSize: 16,
    fontWeight: '600',
    color: '#fff',
    flex: 1,
  },
  untitled: {
    fontSize: 16,
    fontWeight: '600',
    color: '#666',
    fontStyle: 'italic',
    flex: 1,
  },
  audioIndicator: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: '#1a2a3e',
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: 8,
  },
  content: {
    fontSize: 14,
    color: '#aaa',
    lineHeight: 20,
    marginBottom: 12,
  },
  tagsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginBottom: 12,
  },
  tag: {
    backgroundColor: '#2a2a4e',
    borderRadius: 4,
    paddingHorizontal: 8,
    paddingVertical: 4,
    marginRight: 6,
    marginBottom: 4,
  },
  tagText: {
    fontSize: 11,
    color: '#aaa',
  },
  moreTags: {
    fontSize: 11,
    color: '#666',
    alignSelf: 'center',
    marginLeft: 4,
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: '#2a2a4e',
  },
  metadata: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  metaItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: 12,
  },
  metaText: {
    fontSize: 11,
    color: '#888',
    marginLeft: 4,
  },
  dateContainer: {
    alignItems: 'flex-end',
  },
  projectName: {
    fontSize: 11,
    color: '#4a9eff',
    marginBottom: 2,
  },
  date: {
    fontSize: 12,
    color: '#666',
  },
});

export default NoteCard;
