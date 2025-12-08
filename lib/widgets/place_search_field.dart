import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Widget para búsqueda de lugares con autocompletado y reconocimiento de voz
class PlaceSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(String, double, double) onPlaceSelected;
  final bool isLoading;
  final IconData prefixIcon;

  const PlaceSearchField({
    Key? key,
    required this.controller,
    required this.hintText,
    required this.onPlaceSelected,
    this.isLoading = false,
    this.prefixIcon = Icons.search,
  }) : super(key: key);

  @override
  State<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends State<PlaceSearchField> {
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _speechText = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error de voz: ${error.errorMsg}')),
          );
        }
      },
    );
  }

  void _startListening() async {
    if (!_speech.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reconocimiento de voz no disponible')),
      );
      return;
    }

    setState(() {
      _isListening = true;
      _speechText = '';
    });

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _speechText = result.recognizedWords;
          widget.controller.text = _speechText;
          if (result.finalResult) {
            _searchPlaces(_speechText);
          }
        });
      },
      localeId: 'es_ES',
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  void _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    try {
      // Buscar lugares con contexto de Santa Cruz, Bolivia
      final variations = [
        '$query, Santa Cruz de la Sierra, Bolivia',
        '$query, Santa Cruz, Bolivia',
        'Barrio $query, Santa Cruz, Bolivia',
        'Avenida $query, Santa Cruz, Bolivia',
        'Calle $query, Santa Cruz, Bolivia',
      ];

      Set<String> uniqueSuggestions = {};

      for (var searchQuery in variations) {
        try {
          List<Location> locations = await locationFromAddress(searchQuery);
          if (locations.isNotEmpty) {
            uniqueSuggestions.add(searchQuery);
          }
        } catch (e) {
          // Ignorar errores y continuar
        }
      }

      setState(() {
        _suggestions = uniqueSuggestions.take(5).toList();
        _showSuggestions = _suggestions.isNotEmpty;
      });
    } catch (e) {
      print('Error buscando lugares: $e');
    }
  }

  void _selectPlace(String place) async {
    widget.controller.text = place;
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });

    try {
      List<Location> locations = await locationFromAddress(place);
      if (locations.isNotEmpty) {
        final location = locations.first;
        widget.onPlaceSelected(place, location.latitude, location.longitude);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al buscar ubicación: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: Icon(widget.prefixIcon, size: 20),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  // Botón de voz
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                    onPressed: _isListening ? _stopListening : _startListening,
                    tooltip: _isListening ? 'Detener' : 'Hablar',
                  ),
                  // Botón de búsqueda
                  IconButton(
                    icon: const Icon(Icons.search, size: 20),
                    onPressed: () {
                      if (widget.controller.text.isNotEmpty) {
                        _selectPlace(
                          '${widget.controller.text}, Santa Cruz de la Sierra, Bolivia',
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          onChanged: (value) {
            if (value.length >= 3) {
              _searchPlaces(value);
            } else {
              setState(() {
                _suggestions = [];
                _showSuggestions = false;
              });
            }
          },
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _selectPlace('$value, Santa Cruz de la Sierra, Bolivia');
            }
          },
        ),

        // Indicador de escucha
        if (_isListening)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.mic, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _speechText.isEmpty ? 'Escuchando...' : _speechText,
                    style: TextStyle(color: Colors.red.shade900, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

        // Sugerencias
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  leading: const Icon(Icons.location_on, size: 20),
                  title: Text(suggestion, style: const TextStyle(fontSize: 14)),
                  onTap: () => _selectPlace(suggestion),
                  dense: true,
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}
