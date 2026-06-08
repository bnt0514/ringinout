import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:ringinout/services/billing_service.dart';

class PlayBillingPurchaseService extends ChangeNotifier {
  PlayBillingPurchaseService(this._billingService);

  static const packageName = 'com.bnt0514.ringinout';
  static const plusMonthlyProductId = String.fromEnvironment(
    'RINGINOUT_PLUS_MONTHLY_ID',
    defaultValue: 'ringinout_plus_monthly',
  );
  static const proMonthlyProductId = String.fromEnvironment(
    'RINGINOUT_PRO_MONTHLY_ID',
    defaultValue: 'ringinout_pro_monthly',
  );
  static const removeAdsProductId = String.fromEnvironment(
    'RINGINOUT_REMOVE_ADS_ID',
    defaultValue: 'ringinout_remove_ads',
  );

  final BillingService _billingService;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool _available = false;
  bool _loading = false;
  String? _lastError;
  List<ProductDetails> _products = [];

  bool get available => _available;
  bool get loading => _loading;
  String? get lastError => _lastError;
  List<ProductDetails> get products => List.unmodifiable(_products);

  Future<void> init() async {
    _available = await _iap.isAvailable();
    _purchaseSub ??= _iap.purchaseStream.listen(
      _handlePurchases,
      onError: (Object error) {
        _lastError = error.toString();
        notifyListeners();
      },
    );
    notifyListeners();
  }

  Future<void> loadProducts() async {
    if (!_available) {
      await init();
    }
    if (!_available) return;

    _loading = true;
    _lastError = null;
    notifyListeners();

    final response = await _iap.queryProductDetails({
      plusMonthlyProductId,
      proMonthlyProductId,
      removeAdsProductId,
    });
    _products = response.productDetails;
    if (response.error != null) {
      _lastError = response.error!.message;
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> buyProduct(String productId) async {
    if (_products.isEmpty) {
      await loadProducts();
    }
    ProductDetails? product;
    for (final candidate in _products) {
      if (candidate.id == productId) {
        product = candidate;
        break;
      }
    }
    if (product == null) {
      _lastError = 'Product not found: $productId';
      notifyListeners();
      return false;
    }

    final param = PurchaseParam(
      productDetails: product,
      applicationUserName: await _billingService.getObfuscatedAccountId(),
    );
    if (productId == removeAdsProductId) {
      return _iap.buyNonConsumable(purchaseParam: param);
    }
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        _lastError = purchase.error?.message ?? 'Purchase failed';
        notifyListeners();
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final verified = await _verifyWithServer(purchase);
        if (!verified) {
          _lastError = 'Purchase verification failed';
          notifyListeners();
        }
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<bool> _verifyWithServer(PurchaseDetails purchase) async {
    final token = purchase.verificationData.serverVerificationData;
    if (token.isEmpty) return false;
    final purchaseType =
        purchase.productID == removeAdsProductId ? 'inapp' : 'subscription';

    return _billingService.verifyPurchase(
      store: 'google_play',
      receipt: purchase.verificationData.localVerificationData,
      purchaseToken: token,
      productId: purchase.productID,
      packageName: packageName,
      purchaseType: purchaseType,
    );
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}
