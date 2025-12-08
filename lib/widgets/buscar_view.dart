import 'package:flutter/material.dart';
import '../ruta_model.dart';

/// Widget para la vista de búsqueda de rutas
class BuscarView extends StatelessWidget {
  final TextEditingController searchController;
  final List<LineaRuta> rutasFiltradas;
  final Function(String) onSearchChanged;
  final Function(LineaRuta) onRutaSelected;

  const BuscarView({
    Key? key,
    required this.searchController,
    required this.rutasFiltradas,
    required this.onSearchChanged,
    required this.onRutaSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchPanel(),
        if (rutasFiltradas.isNotEmpty)
          Positioned(top: 70, left: 0, right: 0, child: _buildSearchResults()),
      ],
    );
  }

  Widget _buildSearchPanel() {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black12)],
      ),
      child: TextField(
        controller: searchController,
        decoration: const InputDecoration(
          hintText: "Buscar línea (ej. L001, Micro 1, etc.)",
          border: InputBorder.none,
          icon: Icon(Icons.search),
        ),
        onChanged: onSearchChanged,
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(maxHeight: 250),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: rutasFiltradas.length,
        itemBuilder: (ctx, i) {
          final r = rutasFiltradas[i];
          final numeroLinea = r.nombre.replaceAll(RegExp(r'L0*'), '');
          final direccion = r.descripcion.contains('Retorno') ? '↩️' : '↗️';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: r.color,
              child: Text(
                numeroLinea,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            title: Text(
              'Línea $numeroLinea $direccion',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              r.descripcion,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            onTap: () => onRutaSelected(r),
          );
        },
      ),
    );
  }
}
