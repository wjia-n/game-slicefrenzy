import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/frenzy_art.dart';
import '../theme/frenzy_themes.dart';

/// Pro screen: Free-vs-Pro comparison, real purchases, tip jar, restore.
/// Graceful when products are not yet configured in Play Console.
class ProScreen extends StatefulWidget {
  final SliceAudio audio;
  final SliceSettings settings;
  final StoreService store;
  const ProScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.proPurchased.addListener(_onPro);
    widget.store.lastThanks.addListener(_onThanks);
    widget.store.purchaseError.addListener(_onError);
  }

  @override
  void dispose() {
    widget.store.proPurchased.removeListener(_onPro);
    widget.store.lastThanks.removeListener(_onThanks);
    widget.store.purchaseError.removeListener(_onError);
    super.dispose();
  }

  void _onPro() {
    if (widget.store.proPurchased.value) {
      widget.settings.setPro(true);
      widget.store.proPurchased.value = false;
    }
  }

  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
      widget.store.lastThanks.value = null;
    }
  }

  void _onError() {
    final msg = widget.store.purchaseError.value;
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
      widget.store.purchaseError.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.settings.theme;
    final store = widget.store;
    final isPro = widget.settings.isPro;
    return Scaffold(
      appBar: AppBar(
        title: Text('Slice Frenzy PRO', style: FrenzyText.display(22, theme)),
        backgroundColor: theme.card,
        foregroundColor: theme.ink,
        elevation: 1,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.skyTop, theme.skyBottom],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _FreeVsPro(theme: theme, isPro: isPro),
            const SizedBox(height: 16),
            if (!store.available || !store.storeReady)
              _StoreNotice(theme: theme, store: store)
            else if (isPro)
              _ProActive(theme: theme)
            else
              _BuyPro(
                  theme: theme,
                  store: store,
                  onBuy: () {
                    widget.audio.click();
                    store.buyPro();
                  }),
            const SizedBox(height: 16),
            _TipJar(theme: theme, store: store, audio: widget.audio),
            const SizedBox(height: 16),
            _RestoreRow(
                theme: theme,
                store: store,
                onRestore: () {
                  widget.audio.click();
                  store.restore();
                }),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Pro product: ${StoreService.proId}\nTips: ${StoreService.coffeeId}, ${StoreService.chocolateId}',
                textAlign: TextAlign.center,
                style: FrenzyText.label(10, theme)
                    .copyWith(color: theme.ink.withValues(alpha: 0.4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeVsPro extends StatelessWidget {
  final FrenzyThemeDef theme;
  final bool isPro;
  const _FreeVsPro({required this.theme, required this.isPro});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['Classic, Zen & Blitz modes', true, true],
      ['Endless mode (no clock, 3 lives)', false, true],
      ['Easy & Normal difficulty', true, true],
      ['Hard difficulty (frenzy speed)', false, true],
      ['8 market themes', true, true],
      ['4 exclusive Pro themes', false, true],
      ['Custom theme creator (design your own)', false, true],
      ['5 blade styles', true, true],
      ['5 Pro blades + custom blade creator', false, true],
      ['Best scores per mode', true, true],
    ];
    return Container(
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(0, 3),
              blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(child: Container()),
                SizedBox(
                    width: 52,
                    child: Text('FREE',
                        textAlign: TextAlign.center,
                        style: FrenzyText.label(11, theme))),
                SizedBox(
                    width: 52,
                    child: Text('PRO',
                        textAlign: TextAlign.center,
                        style: FrenzyText.label(11, theme)
                            .copyWith(color: theme.accent))),
              ],
            ),
          ),
          const Divider(height: 1),
          ...rows.map((r) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(r[0] as String,
                            style: FrenzyText.body(13, theme))),
                    SizedBox(
                        width: 52,
                        child: Icon(
                            (r[1] as bool) ? Icons.check : Icons.close,
                            size: 18,
                            color: (r[1] as bool)
                                ? theme.ink.withValues(alpha: 0.7)
                                : theme.ink.withValues(alpha: 0.25))),
                    SizedBox(
                        width: 52,
                        child: Icon(Icons.check,
                            size: 18, color: theme.accent)),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StoreNotice extends StatelessWidget {
  final FrenzyThemeDef theme;
  final StoreService store;
  const _StoreNotice({required this.theme, required this.store});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.storefront,
              color: theme.ink.withValues(alpha: 0.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              store.error ??
                  'Purchases become available after the store products are set up.',
              style: FrenzyText.body(13, theme)
                  .copyWith(color: theme.ink.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyPro extends StatelessWidget {
  final FrenzyThemeDef theme;
  final StoreService store;
  final VoidCallback onBuy;
  const _BuyPro(
      {required this.theme, required this.store, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final p = store.proProduct;
    return GestureDetector(
      onTap: store.purchaseInProgress.value ? null : onBuy,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.accent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: theme.accent.withValues(alpha: 0.4),
                offset: const Offset(0, 6),
                blurRadius: 14),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: theme.accentInk, size: 26),
                const SizedBox(width: 8),
                Text('Unlock PRO', style: FrenzyText.onAccent(22, theme)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              p != null
                  ? 'One-time purchase · ${p.price}'
                  : 'One-time purchase',
              style: FrenzyText.onAccent(13, theme)
                  .copyWith(color: theme.accentInk.withValues(alpha: 0.85)),
            ),
            if (store.purchaseInProgress.value)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: CircularProgressIndicator(
                    color: theme.accentInk),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProActive extends StatelessWidget {
  final FrenzyThemeDef theme;
  const _ProActive({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.accent, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified, color: theme.accent, size: 26),
          const SizedBox(width: 10),
          Text('PRO is active — slice away!',
              style: FrenzyText.label(15, theme)),
        ],
      ),
    );
  }
}

class _TipJar extends StatelessWidget {
  final FrenzyThemeDef theme;
  final StoreService store;
  final SliceAudio audio;
  const _TipJar(
      {required this.theme, required this.store, required this.audio});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(0, 3),
              blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TIP JAR', style: FrenzyText.label(12, theme)),
          const SizedBox(height: 4),
          Text(
            'Love the game? Toss a tip in the jar — it keeps the fruit flying.',
            style: FrenzyText.body(13, theme)
                .copyWith(color: theme.ink.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _TipButton(
                      theme: theme,
                      store: store,
                      audio: audio,
                      product: store.coffeeProduct,
                      emoji: '☕',
                      label: 'Coffee')),
              const SizedBox(width: 10),
              Expanded(
                  child: _TipButton(
                      theme: theme,
                      store: store,
                      audio: audio,
                      product: store.chocolateProduct,
                      emoji: '🍫',
                      label: 'Chocolate')),
            ],
          ),
        ],
      ),
    );
  }
}

class _TipButton extends StatelessWidget {
  final FrenzyThemeDef theme;
  final StoreService store;
  final SliceAudio audio;
  final ProductDetails? product;
  final String emoji;
  final String label;
  const _TipButton({
    required this.theme,
    required this.store,
    required this.audio,
    required this.product,
    required this.emoji,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = product != null && !store.purchaseInProgress.value;
    return GestureDetector(
      onTap: enabled
          ? () {
              audio.click();
              store.buyTip(product!);
            }
          : null,
      child: Opacity(
        opacity: product == null ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: theme.ink.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(label, style: FrenzyText.label(13, theme)),
              Text(
                product?.price ?? 'soon',
                style: FrenzyText.body(12, theme)
                    .copyWith(color: theme.ink.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestoreRow extends StatelessWidget {
  final FrenzyThemeDef theme;
  final StoreService store;
  final VoidCallback onRestore;
  const _RestoreRow(
      {required this.theme, required this.store, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: store.available ? onRestore : null,
        icon: Icon(Icons.restore, color: theme.ink.withValues(alpha: 0.7)),
        label: Text('Restore purchases',
            style: FrenzyText.body(14, theme)
                .copyWith(color: theme.ink.withValues(alpha: 0.7))),
      ),
    );
  }
}
