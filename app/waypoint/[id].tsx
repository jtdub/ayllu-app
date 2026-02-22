import { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  TextInput,
  Alert,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams, useRouter, Stack } from 'expo-router';
import { useDatabase } from '@/hooks/useDatabase';
import type { Waypoint, Photo, FieldNote } from '@/types';
import { formatDate, formatCoordinates } from '@/utils';

export default function WaypointDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const { waypointRepository, photoRepository, fieldNoteRepository } = useDatabase();

  const [waypoint, setWaypoint] = useState<Waypoint | null>(null);
  const [photos, setPhotos] = useState<Photo[]>([]);
  const [notes, setNotes] = useState<FieldNote[]>([]);
  const [isEditing, setIsEditing] = useState(false);
  const [editedName, setEditedName] = useState('');
  const [editedDescription, setEditedDescription] = useState('');

  useEffect(() => {
    if (id) {
      loadWaypoint();
    }
  }, [id, waypointRepository]);

  const loadWaypoint = async () => {
    if (!waypointRepository || !id) return;

    const data = await waypointRepository.getById(id);
    setWaypoint(data);

    if (data) {
      setEditedName(data.name);
      setEditedDescription(data.description || '');

      // Load related data
      if (photoRepository) {
        const ph = await photoRepository.getByWaypoint(id);
        setPhotos(ph);
      }

      if (fieldNoteRepository) {
        const nt = await fieldNoteRepository.getByWaypoint(id);
        setNotes(nt);
      }
    }
  };

  const handleSave = async () => {
    if (!waypointRepository || !waypoint) return;

    try {
      await waypointRepository.update(waypoint.id, {
        name: editedName.trim(),
        description: editedDescription.trim() || null,
      });

      setWaypoint({
        ...waypoint,
        name: editedName.trim(),
        description: editedDescription.trim() || null,
      });
      setIsEditing(false);
    } catch (error) {
      console.error('Failed to update waypoint:', error);
      Alert.alert('Error', 'Failed to update waypoint');
    }
  };

  const handleDelete = () => {
    Alert.alert(
      'Delete Waypoint',
      'This will permanently delete this waypoint. Photos and notes will be unlinked but not deleted.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            if (waypointRepository && waypoint) {
              await waypointRepository.delete(waypoint.id);
              router.back();
            }
          },
        },
      ]
    );
  };

  if (!waypoint) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.loadingText}>Loading...</Text>
      </View>
    );
  }

  return (
    <>
      <Stack.Screen
        options={{
          title: waypoint.name,
          headerRight: () => (
            <TouchableOpacity onPress={() => setIsEditing(!isEditing)} style={styles.headerButton}>
              <Ionicons name={isEditing ? 'close' : 'create'} size={22} color="#4a9eff" />
            </TouchableOpacity>
          ),
        }}
      />

      <ScrollView style={styles.container} contentContainerStyle={styles.content}>
        {/* Waypoint Info */}
        <View style={styles.card}>
          {isEditing ? (
            <>
              <TextInput
                style={styles.editInput}
                value={editedName}
                onChangeText={setEditedName}
                placeholder="Waypoint name"
                placeholderTextColor="#666"
              />
              <TextInput
                style={[styles.editInput, styles.editDescription]}
                value={editedDescription}
                onChangeText={setEditedDescription}
                placeholder="Description (optional)"
                placeholderTextColor="#666"
                multiline
              />
              <TouchableOpacity style={styles.saveButton} onPress={handleSave}>
                <Text style={styles.saveButtonText}>Save Changes</Text>
              </TouchableOpacity>
            </>
          ) : (
            <>
              <Text style={styles.waypointName}>{waypoint.name}</Text>
              {waypoint.description && (
                <Text style={styles.waypointDescription}>{waypoint.description}</Text>
              )}
            </>
          )}
        </View>

        {/* Location Data */}
        <View style={styles.card}>
          <Text style={styles.sectionTitle}>Location</Text>

          <View style={styles.coordinatesBox}>
            <Text style={styles.coordinates}>
              {formatCoordinates(waypoint.latitude, waypoint.longitude)}
            </Text>
          </View>

          <View style={styles.dataGrid}>
            <View style={styles.dataItem}>
              <Ionicons name="arrow-up" size={16} color="#4a9eff" />
              <Text style={styles.dataLabel}>Altitude</Text>
              <Text style={styles.dataValue}>
                {waypoint.altitude !== null ? `${waypoint.altitude.toFixed(1)} m` : '—'}
              </Text>
            </View>

            <View style={styles.dataItem}>
              <Ionicons name="radio-button-on" size={16} color="#4a9eff" />
              <Text style={styles.dataLabel}>Accuracy</Text>
              <Text style={styles.dataValue}>
                {waypoint.accuracy !== null ? `±${waypoint.accuracy.toFixed(1)} m` : '—'}
              </Text>
            </View>

            <View style={styles.dataItem}>
              <Ionicons name="compass" size={16} color="#4a9eff" />
              <Text style={styles.dataLabel}>Heading</Text>
              <Text style={styles.dataValue}>
                {waypoint.heading !== null ? `${waypoint.heading.toFixed(0)}°` : '—'}
              </Text>
            </View>

            <View style={styles.dataItem}>
              <Ionicons name="speedometer" size={16} color="#4a9eff" />
              <Text style={styles.dataLabel}>Speed</Text>
              <Text style={styles.dataValue}>
                {waypoint.speed !== null ? `${waypoint.speed.toFixed(1)} m/s` : '—'}
              </Text>
            </View>
          </View>
        </View>

        {/* Timestamp */}
        <View style={styles.card}>
          <Text style={styles.sectionTitle}>Recorded</Text>
          <View style={styles.dateRow}>
            <Ionicons name="time" size={16} color="#888" />
            <Text style={styles.dateText}>{formatDate(waypoint.timestamp, true)}</Text>
          </View>
        </View>

        {/* Tags */}
        {waypoint.tags.length > 0 && (
          <View style={styles.card}>
            <Text style={styles.sectionTitle}>Tags</Text>
            <View style={styles.tagsContainer}>
              {waypoint.tags.map((tag, index) => (
                <View key={index} style={styles.tag}>
                  <Text style={styles.tagText}>{tag}</Text>
                </View>
              ))}
            </View>
          </View>
        )}

        {/* Linked Photos */}
        {photos.length > 0 && (
          <View style={styles.card}>
            <Text style={styles.sectionTitle}>Photos ({photos.length})</Text>
            {photos.map((photo) => (
              <View key={photo.id} style={styles.listItem}>
                <Ionicons name="image" size={18} color="#4a9eff" />
                <View style={styles.listItemText}>
                  <Text style={styles.listItemTitle}>{photo.filename}</Text>
                  <Text style={styles.listItemSubtitle}>{formatDate(photo.capturedAt, true)}</Text>
                </View>
              </View>
            ))}
          </View>
        )}

        {/* Linked Notes */}
        {notes.length > 0 && (
          <View style={styles.card}>
            <Text style={styles.sectionTitle}>Notes ({notes.length})</Text>
            {notes.map((note) => (
              <View key={note.id} style={styles.listItem}>
                <Ionicons name="document-text" size={18} color="#4a9eff" />
                <View style={styles.listItemText}>
                  <Text style={styles.listItemTitle} numberOfLines={2}>
                    {note.title || note.content.substring(0, 50)}
                  </Text>
                  <Text style={styles.listItemSubtitle}>{formatDate(note.timestamp, true)}</Text>
                </View>
              </View>
            ))}
          </View>
        )}

        {/* Delete Action */}
        <TouchableOpacity style={[styles.actionButton, styles.deleteAction]} onPress={handleDelete}>
          <Ionicons name="trash" size={20} color="#ff6b6b" />
          <Text style={[styles.actionText, styles.deleteText]}>Delete Waypoint</Text>
        </TouchableOpacity>
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f0f1a',
  },
  centerContainer: {
    flex: 1,
    backgroundColor: '#0f0f1a',
    alignItems: 'center',
    justifyContent: 'center',
  },
  loadingText: {
    color: '#888',
  },
  content: {
    padding: 16,
    paddingBottom: 40,
  },
  headerButton: {
    padding: 8,
  },
  card: {
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  waypointName: {
    fontSize: 24,
    fontWeight: '600',
    color: '#fff',
    marginBottom: 8,
  },
  waypointDescription: {
    fontSize: 15,
    color: '#aaa',
    lineHeight: 22,
  },
  editInput: {
    backgroundColor: '#0f0f1a',
    borderRadius: 8,
    padding: 12,
    color: '#fff',
    fontSize: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  editDescription: {
    minHeight: 80,
    textAlignVertical: 'top',
  },
  saveButton: {
    backgroundColor: '#4a9eff',
    borderRadius: 8,
    padding: 14,
    alignItems: 'center',
  },
  saveButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '600',
    color: '#888',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 12,
  },
  coordinatesBox: {
    backgroundColor: '#0f0f1a',
    borderRadius: 8,
    padding: 12,
    alignItems: 'center',
    marginBottom: 16,
  },
  coordinates: {
    fontSize: 16,
    fontFamily: 'monospace',
    color: '#4a9eff',
  },
  dataGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  dataItem: {
    width: '50%',
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
  },
  dataLabel: {
    fontSize: 13,
    color: '#888',
    marginLeft: 8,
  },
  dataValue: {
    fontSize: 14,
    color: '#fff',
    marginLeft: 'auto',
    paddingRight: 16,
  },
  dateRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  dateText: {
    fontSize: 15,
    color: '#fff',
    marginLeft: 8,
  },
  tagsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  tag: {
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
  },
  listItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: '#2a2a4e',
  },
  listItemText: {
    flex: 1,
    marginLeft: 12,
  },
  listItemTitle: {
    fontSize: 14,
    color: '#fff',
  },
  listItemSubtitle: {
    fontSize: 12,
    color: '#888',
    marginTop: 2,
  },
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    padding: 16,
    marginTop: 8,
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  deleteAction: {
    borderColor: '#ff6b6b33',
  },
  actionText: {
    fontSize: 16,
    color: '#fff',
    marginLeft: 12,
  },
  deleteText: {
    color: '#ff6b6b',
  },
});
