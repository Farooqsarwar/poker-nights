import re

with open('lib/screens/public/auth_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

card_method = '''  Widget _buildCard(BuildContext context) {
    final device = AppBreakpoints.deviceOf(context);
    final twoColumn = device.isDesktop || device.isLargeDesktop;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _title,
          style: AppTypography.display(
            size: AppFontSizes.xxl,
            weight: FontWeight.w700,
          ),
        ),
        if (_isForgot) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Enter your email and we'll send a link to set a new one.",
            style: const TextStyle(
              color: Color(0xFFB8B8C2),
              fontSize: 13.5,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (!_isForgot) ...[
          _GoogleSignInButton(
            onPressed: _loading ? () {} : _handleGoogleSignIn,
            loading: _loading,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: const [
              Expanded(child: Divider(color: Color(0xFF242428))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'or continue with email',
                  style: TextStyle(
                    color: Color(0xFF9A9AA6),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Color(0xFF242428))),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (_isRegister) ...[
          AppTextField(
            controller: _nameController,
            label: null,
            placeholder: 'Full Name',
            textCapitalization: TextCapitalization.words,
            suffixIcon: _trailing(Icons.person_outline),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        AppTextField(
          controller: _emailController,
          label: null,
          placeholder: 'Email address',
          keyboardType: TextInputType.emailAddress,
          suffixIcon: _trailing(Icons.mail_outline),
        ),
        if (!_isForgot) ...[
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _passwordController,
            label: null,
            placeholder: 'Password',
            obscureText: !_showPw,
            suffixIcon: _eyeToggle(),
          ),
          if (_isRegister) ...[
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _confirmController,
              label: null,
              placeholder: 'Confirm Password',
              obscureText: !_showPw,
              suffixIcon: _eyeToggle(),
            ),
          ],
        ],
        if (widget.mode == AuthMode.login) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => context.go(RoutePaths.forgotPassword),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: Color(0xFFE5797A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _error!,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.destructiveText,
            ),
          ),
        ],
        if (_success != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _success!,
            style: AppTypography.bodySm.copyWith(color: AppColors.successText),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0A0A0A),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _loading ? null : _handleSubmit,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0A0A0A),
                    ),
                  )
                : Text(
                    _isForgot
                        ? 'Send reset link'
                        : _isRegister
                        ? 'Create Account'
                        : 'Sign In',
                    style: const TextStyle(
                      color: Color(0xFF0A0A0A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        if (!twoColumn) const Spacer(), // Push switch line to the bottom on mobile
        if (!twoColumn) const SizedBox(height: 24),
        if (widget.mode == AuthMode.login) ...[
          _switchLine(
            context,
            prompt: "Don't have an account? ",
            action: 'Create Account',
            onTap: () {
              final next = widget.next;
              if (next != null) {
                context.go(
                  '\?next=\',
                );
              } else {
                context.go(RoutePaths.register);
              }
            },
          ),
        ] else if (_isRegister) ...[
          _switchLine(
            context,
            prompt: 'Already have an account? ',
            action: 'Sign In',
            onTap: () {
              final next = widget.next;
              if (next != null) {
                context.go(
                  '\?next=\',
                );
              } else {
                context.go(RoutePaths.login);
              }
            },
          ),
        ] else ...[
          Center(
            child: InkWell(
              onTap: () => context.go(RoutePaths.login),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Text(
                  'Back to Sign In',
                  style: TextStyle(
                    color: Color(0xFFE5797A),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: twoColumn
          ? Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.cardGlow,
              ),
              child: content,
            )
          : Container(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              // We need expanded content if spacer is used
              height: double.infinity,
              child: content,
            ),
    );
  }'''

code = re.sub(r'  Widget _buildCard\(BuildContext context\) \{.*?(?=  Widget _switchLine)', card_method + '\n\n', code, flags=re.DOTALL)

with open('lib/screens/public/auth_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)
