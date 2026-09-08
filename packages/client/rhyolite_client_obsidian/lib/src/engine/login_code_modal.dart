import 'package:obsidian_dart/obsidian_dart.dart';
import 'package:rhyolite_client_account/rhyolite_client_account.dart';

import '../i18n/i18n.dart';

/// Sign in by pasting a one-time code, for desktops where the browser handoff
/// cannot complete.
///
/// Browser-auth is still the way in: the user signs in on the site, exactly as
/// before. What differs is the return trip. The normal path asks the OS to
/// deliver `obsidian://rhyolite-auth?code=…` back to the app, and on Linux that
/// depends on a desktop entry the app does not install and cannot inspect — a
/// missing `%u`, a stale AppImage path, or a Flatpak/host split all swallow the
/// callback with no error anywhere. This path carries the same one-time code by
/// hand, so nothing outside the browser and this modal has to work.
///
/// The code is the site's, not ours to mint: `/auth?client=code` shows it, and
/// [RpcAccountClient.redeemLoginCode] is the identical call the protocol
/// handler makes. No password is entered here — the site remains the only
/// place that sees one.
///
/// Returns [client] on success (its session is now live), null if cancelled.
Future<RpcAccountClient?> showLoginCodeModal(
  PluginHandle plugin, {
  required RpcAccountClient client,
  required String authWebUrl,
  required void Function(String url) openUrl,
}) async {
  return showModalWith<RpcAccountClient?>(
    plugin,
    build: (ctx) {
      ctx.h3(S.signInWithCode);
      ctx.spaceVertical(px: 8);
      ctx.createEl(
        'p',
        cls: 'rhyolite-setting-desc',
        text: S.loginCodeModalDescription,
      );
      ctx.spaceVertical(px: 12);

      final codeInput = ctx.input(
        type: 'text',
        placeholder: S.loginCodePlaceholder,
      )..focus();
      ctx.spaceVertical(px: 12);

      final loading = ctx.spinner(label: S.loginCodeSigningIn);

      late final List<ButtonRef> buttons;

      Future<void> tryRedeem() async {
        final code = ctx.valueOf(codeInput).trim();
        if (code.isEmpty) return;

        for (final b in buttons) {
          b.setDisabled(value: true);
        }
        loading.show();

        try {
          await client.redeemLoginCode(code);
          ctx.close(client);
        } catch (e) {
          loading.hide();
          for (final b in buttons) {
            b.setDisabled(value: false);
          }
          ctx.showError(S.signInFailed(e));
        }
      }

      buttons = ctx.buttonRow([
        ButtonSpec(S.signInButton, tryRedeem, variant: ButtonVariant.primary),
        // The page that mints the code. Opened from in here so the user is not
        // sent to find it: the modal is reached precisely by people for whom
        // the automatic path already failed once.
        ButtonSpec(
          S.loginCodeOpenPage,
          () => openUrl('$authWebUrl/auth?client=code'),
        ),
        ButtonSpec(S.cancel, () => ctx.close(null)),
      ]);
      ctx
        ..onEnter(codeInput, tryRedeem)
        ..onEscape(() => ctx.close(null));
    },
  );
}
