import { useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  TextInput,
  RefreshControl,
  Alert,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useFocusEffect } from '@react-navigation/native';
import { useDatabase } from '@/hooks/useDatabase';
import { useLocation } from '@/hooks/useLocation';
import type { FieldNote, Project } from '@/types';
import { formatDate, getCurrentTimestamp } from '@/utils';

export default function NotesScreen() {
  const { fieldNoteRepository, projectRepository } = useDatabase();
  const { location } = useLocation();
  const [projects, setProjects] = useState<Project[]>([]);
  const [selectedProject, setSelectedProject] = useState<Project | null>(null);
  const [notes, setNotes] = useState<FieldNote[]>([]);
  const [refreshing, setRefreshing] = useState(false);
  const [newNoteText, setNewNoteText] = useState('');
  const [isComposing, setIsComposing] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  useFocusEffect(
    useCallback(() => {
      loadProjects();
    }, [projectRepository])
  );

  const loadProjects = async () => {
    if (!projectRepository) return;

    try {
      const data = await projectRepository.getAll();
      setProjects(data);

      if (data.length > 0 && !selectedProject) {
        setSelectedProject(data[0]);
      }
    } catch (error) {
      console.error('Failed to load projects:', error);
    }
  };

  useFocusEffect(
    useCallback(() => {
      if (selectedProject) {
        loadNotes();
      }
    }, [selectedProject, fieldNoteRepository])
  );

  const loadNotes = async () => {
    if (!fieldNoteRepository || !selectedProject) return;

    try {
      const data = await fieldNoteRepository.getByProject(selectedProject.id);
      setNotes(data);
    } catch (error) {
      console.error('Failed to load notes:', error);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadNotes();
    setRefreshing(false);
  };

  const handleCreateNote = async () => {
    if (!newNoteText.trim() || !selectedProject || !fieldNoteRepository) return;

    try {
      const note = await fieldNoteRepository.create({
        projectId: selectedProject.id,
        waypointId: null,
        photoId: null,
        title: null,
        content: newNoteText.trim(),
        audioUri: null,
        audioDuration: null,
        transcriptionSource: 'manual',
        transcriptionConfidence: null,
        tags: selectedProject.defaultTags,
        latitude: location?.latitude ?? null,
        longitude: location?.longitude ?? null,
        timestamp: getCurrentTimestamp(),
      });

      setNotes((prev) => [note, ...prev]);
      setNewNoteText('');
      setIsComposing(false);
    } catch (error) {
      console.error('Failed to create note:', error);
      Alert.alert('Error', 'Failed to create note');
    }
  };

  const handleDeleteNote = (note: FieldNote) => {
    Alert.alert('Delete Note', 'Are you sure you want to delete this note?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          if (fieldNoteRepository) {
            await fieldNoteRepository.delete(note.id);
            setNotes((prev) => prev.filter((n) => n.id !== note.id));
          }
        },
      },
    ]);
  };

  const handleSelectProject = () => {
    if (projects.length === 0) {
      Alert.alert('No Projects', 'Create a project first from the Dashboard');
      return;
    }

    Alert.alert(
      'Select Project',
      'Choose a project:',
      projects.map((p) => ({
        text: p.name,
        onPress: () => setSelectedProject(p),
      }))
    );
  };

  const handleSearch = async () => {
    if (!searchQuery.trim() || !fieldNoteRepository || !selectedProject) {
      loadNotes();
      return;
    }

    try {
      const results = await fieldNoteRepository.search(selectedProject.id, searchQuery.trim());
      setNotes(results);
    } catch (error) {
      console.error('Search failed:', error);
    }
  };

  const renderNote = ({ item }: { item: FieldNote }) => (
    <TouchableOpacity style={styles.noteCard} onLongPress={() => handleDeleteNote(item)}>
      {item.title && <Text style={styles.noteTitle}>{item.title}</Text>}
      <Text style={styles.noteContent} numberOfLines={4}>
        {item.content}
      </Text>
      <View style={styles.noteFooter}>
        <View style={styles.noteMetadata}>
          {item.audioUri && (
            <View style={styles.metaItem}>
              <Ionicons name="mic" size={12} color="#4a9eff" />
            </View>
          )}
          {item.latitude !== null && (
            <View style={styles.metaItem}>
              <Ionicons name="location" size={12} color="#4a9eff" />
            </View>
          )}
          {item.tags.length > 0 && (
            <View style={styles.metaItem}>
              <Ionicons name="pricetag" size={12} color="#888" />
              <Text style={styles.metaText}>{item.tags.length}</Text>
            </View>
          )}
        </View>
        <Text style={styles.noteDate}>{formatDate(item.timestamp, true)}</Text>
      </View>
    </TouchableOpacity>
  );

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      {/* Project selector */}
      <TouchableOpacity style={styles.projectSelector} onPress={handleSelectProject}>
        <Ionicons name="folder" size={18} color="#4a9eff" />
        <Text style={styles.projectName}>{selectedProject?.name || 'Select Project'}</Text>
        <Ionicons name="chevron-down" size={18} color="#888" />
      </TouchableOpacity>

      {/* Search bar */}
      <View style={styles.searchContainer}>
        <Ionicons name="search" size={18} color="#888" />
        <TextInput
          style={styles.searchInput}
          placeholder="Search notes..."
          placeholderTextColor="#666"
          value={searchQuery}
          onChangeText={setSearchQuery}
          onSubmitEditing={handleSearch}
          returnKeyType="search"
        />
        {searchQuery.length > 0 && (
          <TouchableOpacity
            onPress={() => {
              setSearchQuery('');
              loadNotes();
            }}
          >
            <Ionicons name="close-circle" size={18} color="#888" />
          </TouchableOpacity>
        )}
      </View>

      {/* Notes list */}
      <FlatList
        data={notes}
        keyExtractor={(item) => item.id}
        renderItem={renderNote}
        contentContainerStyle={styles.list}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#4a9eff" />
        }
        ListEmptyComponent={
          <View style={styles.emptyState}>
            <Ionicons name="document-text-outline" size={64} color="#444" />
            <Text style={styles.emptyTitle}>No Notes Yet</Text>
            <Text style={styles.emptySubtitle}>Start writing field notes for this project</Text>
          </View>
        }
      />

      {/* Compose area */}
      {isComposing ? (
        <View style={styles.composeContainer}>
          <TextInput
            style={styles.composeInput}
            placeholder="Write your field note..."
            placeholderTextColor="#666"
            value={newNoteText}
            onChangeText={setNewNoteText}
            multiline
            autoFocus
          />
          <View style={styles.composeActions}>
            <TouchableOpacity
              style={styles.composeCancel}
              onPress={() => {
                setIsComposing(false);
                setNewNoteText('');
              }}
            >
              <Text style={styles.cancelText}>Cancel</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.composeSave, !newNoteText.trim() && styles.disabledButton]}
              onPress={handleCreateNote}
              disabled={!newNoteText.trim()}
            >
              <Text style={styles.saveText}>Save Note</Text>
            </TouchableOpacity>
          </View>
        </View>
      ) : (
        <TouchableOpacity style={styles.fab} onPress={() => setIsComposing(true)}>
          <Ionicons name="create" size={24} color="#fff" />
        </TouchableOpacity>
      )}
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f0f1a',
  },
  projectSelector: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1a1a2e',
    marginHorizontal: 16,
    marginTop: 16,
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  projectName: {
    flex: 1,
    color: '#fff',
    fontSize: 16,
    marginLeft: 8,
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1a1a2e',
    marginHorizontal: 16,
    marginTop: 12,
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  searchInput: {
    flex: 1,
    color: '#fff',
    fontSize: 15,
    marginLeft: 8,
    paddingVertical: 0,
  },
  list: {
    padding: 16,
    paddingBottom: 100,
  },
  noteCard: {
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#2a2a4e',
  },
  noteTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#fff',
    marginBottom: 6,
  },
  noteContent: {
    fontSize: 14,
    color: '#ccc',
    lineHeight: 20,
  },
  noteFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 12,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: '#2a2a4e',
  },
  noteMetadata: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  metaItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: 12,
  },
  metaText: {
    fontSize: 12,
    color: '#888',
    marginLeft: 4,
  },
  noteDate: {
    fontSize: 12,
    color: '#666',
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
  composeContainer: {
    backgroundColor: '#1a1a2e',
    borderTopWidth: 1,
    borderTopColor: '#2a2a4e',
    padding: 16,
  },
  composeInput: {
    backgroundColor: '#0f0f1a',
    borderRadius: 12,
    padding: 12,
    color: '#fff',
    fontSize: 15,
    minHeight: 100,
    maxHeight: 200,
    textAlignVertical: 'top',
  },
  composeActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    marginTop: 12,
  },
  composeCancel: {
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  cancelText: {
    color: '#888',
    fontSize: 15,
  },
  composeSave: {
    backgroundColor: '#4a9eff',
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 8,
    marginLeft: 12,
  },
  disabledButton: {
    opacity: 0.5,
  },
  saveText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '600',
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
