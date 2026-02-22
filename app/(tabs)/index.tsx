import { useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  RefreshControl,
  Alert,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useFocusEffect } from '@react-navigation/native';
import { useRouter } from 'expo-router';
import { useDatabase } from '@/hooks/useDatabase';
import type { Project } from '@/types';
import { formatDate } from '@/utils';

export default function DashboardScreen() {
  const router = useRouter();
  const { projectRepository } = useDatabase();
  const [projects, setProjects] = useState<Project[]>([]);
  const [refreshing, setRefreshing] = useState(false);
  const [stats, setStats] = useState<
    Record<string, { waypoints: number; photos: number; notes: number }>
  >({});

  const loadProjects = useCallback(async () => {
    if (!projectRepository) return;

    try {
      const data = await projectRepository.getAll();
      setProjects(data);

      // Load stats for each project
      const projectStats: typeof stats = {};
      for (const project of data) {
        const s = await projectRepository.getStats(project.id);
        projectStats[project.id] = {
          waypoints: s.waypointCount,
          photos: s.photoCount,
          notes: s.noteCount,
        };
      }
      setStats(projectStats);
    } catch (error) {
      console.error('Failed to load projects:', error);
    }
  }, [projectRepository]);

  useFocusEffect(
    useCallback(() => {
      loadProjects();
    }, [loadProjects])
  );

  const onRefresh = async () => {
    setRefreshing(true);
    await loadProjects();
    setRefreshing(false);
  };

  const handleCreateProject = () => {
    Alert.prompt(
      'New Project',
      'Enter a name for your field project:',
      async (name) => {
        if (name && name.trim() && projectRepository) {
          try {
            const project = await projectRepository.create({
              name: name.trim(),
              description: null,
              startDate: new Date().toISOString(),
              endDate: null,
              boundingBox: null,
              defaultTags: [],
              customFields: {},
            });
            setProjects((prev) => [project, ...prev]);
          } catch (error) {
            console.error('Failed to create project:', error);
            Alert.alert('Error', 'Failed to create project');
          }
        }
      },
      'plain-text'
    );
  };

  const handleDeleteProject = (project: Project) => {
    Alert.alert(
      'Delete Project',
      `Are you sure you want to delete "${project.name}"? This will delete all associated waypoints, photos, and notes.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            if (projectRepository) {
              await projectRepository.delete(project.id);
              setProjects((prev) => prev.filter((p) => p.id !== project.id));
            }
          },
        },
      ]
    );
  };

  const renderProject = ({ item }: { item: Project }) => {
    const projectStats = stats[item.id] || { waypoints: 0, photos: 0, notes: 0 };

    return (
      <TouchableOpacity
        style={styles.projectCard}
        onPress={() => router.push(`/project/${item.id}`)}
        onLongPress={() => handleDeleteProject(item)}
      >
        <View style={styles.projectHeader}>
          <Text style={styles.projectName}>{item.name}</Text>
          <Ionicons name="chevron-forward" size={20} color="#888" />
        </View>
        {item.description && (
          <Text style={styles.projectDescription} numberOfLines={2}>
            {item.description}
          </Text>
        )}
        <View style={styles.projectStats}>
          <View style={styles.statItem}>
            <Ionicons name="location" size={14} color="#4a9eff" />
            <Text style={styles.statText}>{projectStats.waypoints}</Text>
          </View>
          <View style={styles.statItem}>
            <Ionicons name="images" size={14} color="#4a9eff" />
            <Text style={styles.statText}>{projectStats.photos}</Text>
          </View>
          <View style={styles.statItem}>
            <Ionicons name="document-text" size={14} color="#4a9eff" />
            <Text style={styles.statText}>{projectStats.notes}</Text>
          </View>
          <Text style={styles.dateText}>{formatDate(item.startDate)}</Text>
        </View>
      </TouchableOpacity>
    );
  };

  return (
    <View style={styles.container}>
      <FlatList
        data={projects}
        keyExtractor={(item) => item.id}
        renderItem={renderProject}
        contentContainerStyle={styles.list}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#4a9eff" />
        }
        ListEmptyComponent={
          <View style={styles.emptyState}>
            <Ionicons name="folder-open" size={64} color="#444" />
            <Text style={styles.emptyTitle}>No Projects Yet</Text>
            <Text style={styles.emptySubtitle}>
              Create your first field research project to get started
            </Text>
          </View>
        }
      />

      <TouchableOpacity style={styles.fab} onPress={handleCreateProject}>
        <Ionicons name="add" size={28} color="#fff" />
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f0f1a',
  },
  list: {
    padding: 16,
    paddingBottom: 100,
  },
  projectCard: {
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  projectHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  projectName: {
    fontSize: 18,
    fontWeight: '600',
    color: '#fff',
    flex: 1,
  },
  projectDescription: {
    fontSize: 14,
    color: '#888',
    marginBottom: 12,
  },
  projectStats: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 8,
  },
  statItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: 16,
  },
  statText: {
    fontSize: 13,
    color: '#aaa',
    marginLeft: 4,
  },
  dateText: {
    fontSize: 12,
    color: '#666',
    marginLeft: 'auto',
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 60,
  },
  emptyTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#fff',
    marginTop: 16,
  },
  emptySubtitle: {
    fontSize: 14,
    color: '#888',
    marginTop: 8,
    textAlign: 'center',
    paddingHorizontal: 40,
  },
  fab: {
    position: 'absolute',
    right: 20,
    bottom: 20,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#4a9eff',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
});
