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
import type { Project, Waypoint, Photo, FieldNote } from '@/types';
import { formatDate } from '@/utils';

export default function ProjectDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const { projectRepository, waypointRepository, photoRepository, fieldNoteRepository } =
    useDatabase();

  const [project, setProject] = useState<Project | null>(null);
  const [waypoints, setWaypoints] = useState<Waypoint[]>([]);
  const [photos, setPhotos] = useState<Photo[]>([]);
  const [notes, setNotes] = useState<FieldNote[]>([]);
  const [isEditing, setIsEditing] = useState(false);
  const [editedName, setEditedName] = useState('');
  const [editedDescription, setEditedDescription] = useState('');

  useEffect(() => {
    if (id) {
      loadProject();
    }
  }, [id, projectRepository]);

  const loadProject = async () => {
    if (!projectRepository || !id) return;

    const data = await projectRepository.getById(id);
    setProject(data);

    if (data) {
      setEditedName(data.name);
      setEditedDescription(data.description || '');
    }

    // Load related data
    if (waypointRepository) {
      const wp = await waypointRepository.getByProject(id);
      setWaypoints(wp);
    }

    if (photoRepository) {
      const ph = await photoRepository.getByProject(id);
      setPhotos(ph);
    }

    if (fieldNoteRepository) {
      const nt = await fieldNoteRepository.getByProject(id);
      setNotes(nt);
    }
  };

  const handleSave = async () => {
    if (!projectRepository || !project) return;

    try {
      await projectRepository.update(project.id, {
        name: editedName.trim(),
        description: editedDescription.trim() || null,
      });

      setProject({
        ...project,
        name: editedName.trim(),
        description: editedDescription.trim() || null,
      });
      setIsEditing(false);
    } catch (error) {
      console.error('Failed to update project:', error);
      Alert.alert('Error', 'Failed to update project');
    }
  };

  const handleExport = () => {
    if (project) {
      router.push(`/export/${project.id}`);
    }
  };

  const handleDelete = () => {
    Alert.alert(
      'Delete Project',
      'This will permanently delete this project and all associated data. This cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            if (projectRepository && project) {
              await projectRepository.delete(project.id);
              router.back();
            }
          },
        },
      ]
    );
  };

  if (!project) {
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
          title: project.name,
          headerRight: () => (
            <TouchableOpacity onPress={() => setIsEditing(!isEditing)} style={styles.headerButton}>
              <Ionicons name={isEditing ? 'close' : 'create'} size={22} color="#4a9eff" />
            </TouchableOpacity>
          ),
        }}
      />

      <ScrollView style={styles.container} contentContainerStyle={styles.content}>
        {/* Project Info */}
        <View style={styles.card}>
          {isEditing ? (
            <>
              <TextInput
                style={styles.editInput}
                value={editedName}
                onChangeText={setEditedName}
                placeholder="Project name"
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
              <Text style={styles.projectName}>{project.name}</Text>
              {project.description && (
                <Text style={styles.projectDescription}>{project.description}</Text>
              )}
              <View style={styles.dateRow}>
                <Ionicons name="calendar" size={14} color="#888" />
                <Text style={styles.dateText}>Started {formatDate(project.startDate)}</Text>
              </View>
            </>
          )}
        </View>

        {/* Statistics */}
        <View style={styles.statsGrid}>
          <View style={styles.statCard}>
            <Ionicons name="location" size={28} color="#4a9eff" />
            <Text style={styles.statNumber}>{waypoints.length}</Text>
            <Text style={styles.statLabel}>Waypoints</Text>
          </View>
          <View style={styles.statCard}>
            <Ionicons name="images" size={28} color="#4a9eff" />
            <Text style={styles.statNumber}>{photos.length}</Text>
            <Text style={styles.statLabel}>Photos</Text>
          </View>
          <View style={styles.statCard}>
            <Ionicons name="document-text" size={28} color="#4a9eff" />
            <Text style={styles.statNumber}>{notes.length}</Text>
            <Text style={styles.statLabel}>Notes</Text>
          </View>
        </View>

        {/* Tags */}
        {project.defaultTags.length > 0 && (
          <View style={styles.card}>
            <Text style={styles.sectionTitle}>Default Tags</Text>
            <View style={styles.tagsContainer}>
              {project.defaultTags.map((tag, index) => (
                <View key={index} style={styles.tag}>
                  <Text style={styles.tagText}>{tag}</Text>
                </View>
              ))}
            </View>
          </View>
        )}

        {/* Recent Waypoints */}
        {waypoints.length > 0 && (
          <View style={styles.card}>
            <Text style={styles.sectionTitle}>Recent Waypoints</Text>
            {waypoints.slice(0, 5).map((wp) => (
              <TouchableOpacity
                key={wp.id}
                style={styles.listItem}
                onPress={() => router.push(`/waypoint/${wp.id}`)}
              >
                <Ionicons name="location" size={18} color="#4a9eff" />
                <View style={styles.listItemText}>
                  <Text style={styles.listItemTitle}>{wp.name}</Text>
                  <Text style={styles.listItemSubtitle}>
                    {wp.latitude.toFixed(6)}, {wp.longitude.toFixed(6)}
                  </Text>
                </View>
                <Ionicons name="chevron-forward" size={18} color="#888" />
              </TouchableOpacity>
            ))}
          </View>
        )}

        {/* Actions */}
        <View style={styles.actionsCard}>
          <TouchableOpacity style={styles.actionButton} onPress={handleExport}>
            <Ionicons name="download" size={20} color="#4a9eff" />
            <Text style={styles.actionText}>Export Data</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.actionButton, styles.deleteAction]}
            onPress={handleDelete}
          >
            <Ionicons name="trash" size={20} color="#ff6b6b" />
            <Text style={[styles.actionText, styles.deleteText]}>Delete Project</Text>
          </TouchableOpacity>
        </View>
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
  projectName: {
    fontSize: 24,
    fontWeight: '600',
    color: '#fff',
    marginBottom: 8,
  },
  projectDescription: {
    fontSize: 15,
    color: '#aaa',
    lineHeight: 22,
    marginBottom: 12,
  },
  dateRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  dateText: {
    fontSize: 13,
    color: '#888',
    marginLeft: 6,
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
  statsGrid: {
    flexDirection: 'row',
    marginBottom: 16,
  },
  statCard: {
    flex: 1,
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
    marginHorizontal: 4,
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  statNumber: {
    fontSize: 24,
    fontWeight: '700',
    color: '#fff',
    marginTop: 8,
  },
  statLabel: {
    fontSize: 12,
    color: '#888',
    marginTop: 4,
  },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '600',
    color: '#888',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 12,
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
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#2a2a4e',
  },
  listItemText: {
    flex: 1,
    marginLeft: 12,
  },
  listItemTitle: {
    fontSize: 15,
    color: '#fff',
  },
  listItemSubtitle: {
    fontSize: 12,
    color: '#888',
    marginTop: 2,
    fontFamily: 'monospace',
  },
  actionsCard: {
    marginTop: 8,
  },
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
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
