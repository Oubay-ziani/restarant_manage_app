import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SmartMenuItemImage extends StatelessWidget {
  final String imageUrl;
  final String category;
  final double? width;
  final double? height;
  final BoxFit fit;

  const SmartMenuItemImage({
    super.key,
    required this.imageUrl,
    required this.category,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Base64 Data URL (e.g. data:image/png;base64,...)
    if (imageUrl.startsWith('data:image/')) {
      try {
        final commaIndex = imageUrl.indexOf(',');
        final base64Str = commaIndex != -1 ? imageUrl.substring(commaIndex + 1) : imageUrl;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallbackIcon(),
        );
      } catch (e) {
        return _buildFallbackIcon();
      }
    }

    // 2. Local Asset image (e.g. assets/images/...)
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallbackIcon(),
      );
    }

    // 3. Web HTTPS/HTTP URL
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallbackIcon(),
      );
    }

    // 4. File Path (e.g. /path/to/file or C:\path\to\file)
    if (imageUrl.startsWith('/') || imageUrl.contains(':\\') || imageUrl.contains(':/')) {
      try {
        return Image.file(
          File(imageUrl),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallbackIcon(),
        );
      } catch (_) {
        return _buildFallbackIcon();
      }
    }

    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    final Map<String, IconData> icons = {
      'steak': Icons.food_bank,
      'chicken': Icons.set_meal,
      'kefta': Icons.lunch_dining,
      'sausage': Icons.fastfood,
      'grill': Icons.outdoor_grill,
      'beverages': Icons.local_cafe,
      'sides': Icons.rice_bowl,
    };
    final icon = icons[category.toLowerCase()] ?? Icons.restaurant;
    return Container(
      width: width,
      height: height,
      color: AppTheme.primaryColor.withValues(alpha: 0.08),
      child: Center(
        child: Icon(icon, color: AppTheme.primaryColor, size: 28),
      ),
    );
  }
}
