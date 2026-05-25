// saved_properties_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/providers.dart';
import '../../widgets/property_card.dart';

class SavedPropertiesScreen extends ConsumerWidget {
  const SavedPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedPropertiesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Saved Properties')),
      body: savedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (properties) => properties.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite_outline, size: 64, color: AppTheme.textTertiary),
                    const SizedBox(height: 16),
                    Text('No saved properties', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Text('Tap the heart icon on any property to save it', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 24),
                    ElevatedButton(onPressed: () => context.go('/home'), child: const Text('Browse Properties')),
                  ],
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72,
                ),
                itemCount: properties.length,
                itemBuilder: (_, i) => PropertyCard(
                  property: properties[i],
                  onTap: () => context.push('/property/${properties[i].id}'),
                ),
              ),
      ),
    );
  }
}