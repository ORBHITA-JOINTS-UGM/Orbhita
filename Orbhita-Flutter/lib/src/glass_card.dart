import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme.dart';

/// Frosted card holding the Google sign-in button and legal text.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.radius,
    required this.padding,
    required this.small,
    required this.tiny,
    required this.onContinue,
  });

  final double radius;
  final EdgeInsets padding;
  final bool small;
  final bool tiny;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 32,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Pressable(
                onTap: onContinue,
                color: Colors.white.withValues(alpha: 0.95),
                radius: 14,
                shadows: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
                child: SizedBox(
                  height: small ? 46 : 48,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tiny ? 14 : (small ? 10 : 14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GoogleLogo(size: small ? 16 : 18),
                        SizedBox(width: tiny ? 6 : (small ? 8 : 10)),
                        Flexible(
                          child: Text(
                            'Continue with Google',
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: T(
                              tiny ? 12 : (small ? 12.5 : 13),
                              w: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: small ? 14 : 18),
              Text(
                'By continuing, you agree to our Terms and Privacy Policy.',
                textAlign: TextAlign.center,
                style: T(
                  small ? 9.5 : 10,
                  color: Colors.white.withValues(alpha: 0.8),
                  ls: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
