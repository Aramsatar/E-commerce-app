import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../models/product_model.dart';

/// Controller to manage user favorite/wishlist products
class FavouritesController extends GetxController {
  static FavouritesController get instance => Get.find();

  // Variables
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // RxVariables for observable state
  RxList<ProductModel> favouriteProducts = <ProductModel>[].obs;
  RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchUserFavourites();
  }

  /// Get User Wishlist from Firebase
  Future<void> fetchUserFavourites() async {
    try {
      isLoading.value = true;

      // Check if user is logged in
      final user = _auth.currentUser;
      if (user == null) {
        favouriteProducts.clear();
        return;
      }

      // Fetch user's favorites from Firestore
      final favoritesDoc = await _db
          .collection('Users')
          .doc(user.uid)
          .collection('Favourites')
          .get();

      // Clear previous data
      favouriteProducts.clear();

      // Process snapshot
      if (favoritesDoc.docs.isNotEmpty) {
        // Get product IDs
        final productIds = favoritesDoc.docs.map((doc) => doc.id).toList();

        // Fetch product details for each favorite
        for (var productId in productIds) {
          final productDoc =
              await _db.collection('Products').doc(productId).get();

          if (productDoc.exists) {
            final product = ProductModel.fromSnapshot(productDoc);
            favouriteProducts.add(product);
          }
        }
      }
    } catch (e) {
      throw 'Something went wrong while fetching favorites: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Add or Remove Product from Wishlist
  Future<void> toggleFavoriteProduct(ProductModel product) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final favouriteRef = _db
          .collection('Users')
          .doc(user.uid)
          .collection('Favourites')
          .doc(product.id);

      // Check if product is already in favorites
      final docSnapshot = await favouriteRef.get();

      if (docSnapshot.exists) {
        // Remove from favorites
        await favouriteRef.delete();
        favouriteProducts.removeWhere((item) => item.id == product.id);
      } else {
        // Add to favorites
        await favouriteRef.set({'addedAt': DateTime.now()});
        favouriteProducts.add(product);
      }
    } catch (e) {
      throw 'Unable to update favorite status: $e';
    }
  }

  /// Check if a product is in the user's favorites
  bool isFavorite(String productId) {
    return favouriteProducts.any((product) => product.id == productId);
  }

  /// Clear all favorites
  Future<void> clearFavorites() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get all favorite documents
      final batch = _db.batch();
      final favorites = await _db
          .collection('Users')
          .doc(user.uid)
          .collection('Favourites')
          .get();

      // Add delete operations to batch
      for (var doc in favorites.docs) {
        batch.delete(doc.reference);
      }

      // Commit the batch
      await batch.commit();

      // Clear local list
      favouriteProducts.clear();
    } catch (e) {
      throw 'Unable to clear favorites: $e';
    }
  }
}
