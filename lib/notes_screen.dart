import 'package:flutter/material.dart';
import 'services/bible_service.dart';

class NotesScreen extends StatefulWidget {
  final BibleService bibleService;

  const NotesScreen({super.key, required this.bibleService});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Map<String, dynamic>> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await widget.bibleService.getNotes();
    setState(() {
      _notes = notes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: _notes.isEmpty
          ? const Center(
              child: Text('No notes yet'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                        '${note['book']} ${note['chapter']}:${note['verse']}'),
                    subtitle: Text(
                      note['note'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteNote(note),
                    ),
                    onTap: () => _editNote(note),
                  ),
                );
              },
            ),
    );
  }

  void _deleteNote(Map<String, dynamic> note) async {
    await widget.bibleService
        .removeNote(note['book'], note['chapter'], note['verse']);
    _loadNotes();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note removed')),
    );
  }

  void _editNote(Map<String, dynamic> note) {
    final TextEditingController controller =
        TextEditingController(text: note['note']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            'Edit Note for ${note['book']} ${note['chapter']}:${note['verse']}'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter your note here',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final updatedNote = controller.text.trim();
              if (updatedNote.isNotEmpty) {
                await widget.bibleService.updateNote(note['id'], updatedNote);
                Navigator.of(context).pop();
                _loadNotes();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Note updated')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
