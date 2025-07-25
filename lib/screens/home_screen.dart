import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'account_screen.dart';
import 'ad_details_screen.dart';
import 'add_ad_screen.dart';
import 'login_screen.dart';
import 'my_ads_screen.dart';
import 'search_results_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool refreshOnStart;
  const HomeScreen({super.key, this.refreshOnStart = false});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCity = 'كل المحافظات';
  String selectedDistrict = 'كل المناطق';
  int? selectedCityId;
  int? selectedRegionId;
  List<Map<String, dynamic>> provinces = [];
  List<Map<String, dynamic>> majorAreas = [];
  List<Map<String, dynamic>> categoriesList = [];
  List<Map<String, dynamic>> subCategoriesList = [];
  Map<String, dynamic>? selectedCategory;
  Map<String, dynamic>? selectedSubCategory;
  int? selectedCategoryId;
  int? selectedSubCategoryId;
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> categories = [
    {'icon': Icons.pets, 'name': 'حيوانات'},
    {'icon': Icons.groups, 'name': 'خدمات'},
    {'icon': Icons.checkroom, 'name': 'أزياء'},
    {'icon': Icons.build, 'name': 'أدوات'},
    {'icon': Icons.chair, 'name': 'أثاث'},
    {'icon': Icons.devices, 'name': 'إلكترونيات'},
    {'icon': Icons.home_work, 'name': 'عقارات'},
    {'icon': Icons.directions_car, 'name': 'مركبات'},
  ];

  // لإعلانات العرض
  List<dynamic> allAds = [];
  bool isLoadingAds = false;
  int currentPageAds = 1;
  final int limitAds = 10;
  bool hasMoreAds = true;
  late ScrollController _adsScrollController;
  String? _username;
  
  // Connectivity variables
  late StreamSubscription<ConnectivityResult> connectivitySubscription;
  bool isConnected = true;
  bool isCheckingConnectivity = true;

  @override
  void initState() {
    super.initState();
    _adsScrollController = ScrollController()..addListener(_onAdsScroll);
    _checkInitialConnectivity();
    _subscribeToConnectivityChanges();
    _checkLoginStatus();
    _fetchOptions();
    fetchAllAds();
  }

  @override
  void dispose() {
    _adsScrollController.dispose();
    connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _fetchOptions() async {
    try {
      final response = await http.get(Uri.parse('https://sahbo-app-api.onrender.com/api/options'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          provinces = List<Map<String, dynamic>>.from(data['Province']);
          majorAreas = List<Map<String, dynamic>>.from(data['majorAreas']);
          categoriesList = List<Map<String, dynamic>>.from(data['categories']);
        subCategoriesList = List<Map<String, dynamic>>.from(data['subCategories']);
        });
      }
    } catch (e) {
      // handle error if needed
    }
  }

  Future<void> _checkInitialConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      isConnected = connectivityResult != ConnectivityResult.none;
      isCheckingConnectivity = false;
    });
  }

  void _subscribeToConnectivityChanges() {
    connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      setState(() {
        isConnected = result != ConnectivityResult.none;
      });
    });
  }

  void _reloadHomeScreen() {
    setState(() {
      // Reset all filters
      selectedCity = 'كل المحافظات';
      selectedDistrict = 'كل المناطق';
      selectedCityId = null;
      selectedRegionId = null;
      selectedCategory = null;
      selectedSubCategory = null;
      selectedCategoryId = null;
      selectedSubCategoryId = null;
      
      // Clear search text
      _searchController.clear();
      
      // Reset ads data
      allAds.clear();
      currentPageAds = 1;
      hasMoreAds = true;
      isLoadingAds = false;
    });
    
    // Reload data
    _fetchOptions();
    fetchAllAds();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final rememberMe = prefs.getBool('rememberMe') ?? false;

    if (token != null) {
      try {
        final response = await http.get(
          Uri.parse('https://sahbo-app-api.onrender.com/api/user/validate-token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          // التوكن صالح، تحميل اسم المستخدم
          setState(() {
            _username = prefs.getString('userName') ?? 'مستخدم';
          });
        } else {
          // التوكن غير صالح، مسح البيانات
          await prefs.clear();
          setState(() {
            _username = null;
          });
        }
      } catch (e) {
        // خطأ في الاتصال، مسح البيانات إذا لم يكن rememberMe مفعلًا
        if (!rememberMe) {
          await prefs.clear();
        }
        setState(() {
          _username = null;
        });
      }
    } else {
      // لا يوجد توكن، مسح البيانات إذا لم يكن rememberMe مفعلًا
      if (!rememberMe) {
        await prefs.clear();
      }
      setState(() {
        _username = null;
      });
    }
  }

  Future<void> fetchAllAds() async {
    if (isLoadingAds || !hasMoreAds) return;

    setState(() {
      isLoadingAds = true;
    });

    try {
      final url = Uri.parse(
        'https://sahbo-app-api.onrender.com/api/ads?page=$currentPageAds&limit=$limitAds',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> fetchedAds = decoded['ads'] ?? [];

        setState(() {
          allAds.addAll(fetchedAds);
          currentPageAds++;
          isLoadingAds = false;
          if (fetchedAds.length < limitAds) {
            hasMoreAds = false;
          }
        });
      } else {
        setState(() {
          isLoadingAds = false;
          hasMoreAds = false;
        });
        debugPrint('Error fetching ads: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoadingAds = false;
        hasMoreAds = false;
      });
      debugPrint('Exception fetching ads: $e');
    }
  }

  Future<void> _showLocationFilterDialog() async {
    Map<String, dynamic>? tempSelectedProvince;
    Map<String, dynamic>? tempSelectedArea;
    List<Map<String, dynamic>> filteredAreas = [];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Color(0xFF4DD0CC), width: 1.5),
              ),
              backgroundColor: Colors.white,
              title: Text(
                'تصفية حسب الموقع',
                style: TextStyle(
                  color: Color(0xFF1E4A47),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: tempSelectedProvince,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'اختر المحافظة',
                        labelStyle: TextStyle(color: Color(0xFF2E7D78)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Color(0xFF4DD0CC), width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Color(0xFF4DD0CC), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Color(0xFF2E7D78), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      dropdownColor: Colors.white,
                      style: TextStyle(
                        color: Color(0xFF1E4A47),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      items: [
                        DropdownMenuItem<Map<String, dynamic>>(
                          value: null,
                          child: Text(
                            'كل المحافظات',
                            style: TextStyle(
                              color: Color(0xFF1E4A47),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        ...provinces.map((province) => DropdownMenuItem(
                              value: province,
                              child: Text(
                                province['name'],
                                style: TextStyle(
                                  color: Color(0xFF1E4A47),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )),
                      ],
                      onChanged: (value) {
                        setStateDialog(() {
                          tempSelectedProvince = value;
                          tempSelectedArea = null;
                          filteredAreas = value == null
                              ? []
                              : majorAreas.where((area) => area['ProvinceId'] == value['id']).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: tempSelectedArea,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'اختر المدينة/المنطقة',
                        labelStyle: TextStyle(color: Color(0xFF2E7D78)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Color(0xFF4DD0CC), width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Color(0xFF4DD0CC), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Color(0xFF2E7D78), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      dropdownColor: Colors.white,
                      style: TextStyle(
                        color: Color(0xFF1E4A47),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      items: [
                        DropdownMenuItem<Map<String, dynamic>>(
                          value: null,
                          child: Text(
                            'كل المناطق',
                            style: TextStyle(
                              color: Color(0xFF1E4A47),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        ...filteredAreas.map((area) => DropdownMenuItem(
                              value: area,
                              child: Text(
                                area['name'],
                                style: TextStyle(
                                  color: Color(0xFF1E4A47),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )),
                      ],
                      onChanged: (value) {
                        setStateDialog(() {
                          tempSelectedArea = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedCity = tempSelectedProvince?['name'] ?? 'كل المحافظات';
                      selectedDistrict = tempSelectedArea?['name'] ?? 'كل المناطق';
                      selectedCityId = tempSelectedProvince?['id'];
                      selectedRegionId = tempSelectedArea?['id'];
                      allAds.clear();
                      currentPageAds = 1;
                      hasMoreAds = true;
                    });
                    Navigator.pop(context);
                    if (selectedCityId != null || selectedRegionId != null) {
                      fetchFilteredAds(reset: true);
                    } else {
                      fetchAllAds();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF7A59),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'تطبيق',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> fetchFilteredAds({bool reset = false}) async {
    if (isLoadingAds || !hasMoreAds) return;

    setState(() {
      isLoadingAds = true;
    });

    try {
      final params = <String, String>{
        'page': '$currentPageAds',
        'limit': '$limitAds',
      };
      if (selectedCityId != null) params['cityId'] = selectedCityId.toString();
      if (selectedRegionId != null) params['regionId'] = selectedRegionId.toString();

      final uri = Uri.https('sahbo-app-api.onrender.com', '/api/ads/search', params);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> fetchedAds = decoded['ads'] ?? [];

        setState(() {
          if (reset) allAds.clear();
          allAds.addAll(fetchedAds);
          currentPageAds++;
          isLoadingAds = false;
          if (fetchedAds.length < limitAds) {
            hasMoreAds = false;
          }
        });
      } else {
        setState(() {
          isLoadingAds = false;
          hasMoreAds = false;
        });
        debugPrint('Error fetching filtered ads: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoadingAds = false;
        hasMoreAds = false;
      });
      debugPrint('Exception fetching filtered ads: $e');
    }
  }

  Future<void> fetchCategoryFilteredAds({bool reset = false}) async {
    if (isLoadingAds || !hasMoreAds) return;

    setState(() {
      isLoadingAds = true;
  });

  try {
    final params = <String, String>{
      'page': '$currentPageAds',
      'limit': '$limitAds',
    };
    if (selectedCategoryId != null) params['categoryId'] = selectedCategoryId.toString();
    if (selectedSubCategoryId != null) params['subCategoryId'] = selectedSubCategoryId.toString();

    final uri = Uri.https('sahbo-app-api.onrender.com', '/api/ads/search-by-category', params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> fetchedAds = decoded['ads'] ?? [];

      setState(() {
        if (reset) allAds.clear();
        allAds.addAll(fetchedAds);
        currentPageAds++;
        isLoadingAds = false;
        if (fetchedAds.length < limitAds) {
          hasMoreAds = false;
        }
      });
    } else {
      setState(() {
        isLoadingAds = false;
        hasMoreAds = false;
      });
      debugPrint('Error fetching filtered ads: ${response.statusCode}');
    }
  } catch (e) {
    setState(() {
      isLoadingAds = false;
      hasMoreAds = false;
    });
    debugPrint('Exception fetching filtered ads: $e');
  }
}
  void _onAdsScroll() {
    if (_adsScrollController.position.pixels >=
      _adsScrollController.position.maxScrollExtent - 200) {
      if (selectedCategoryId != null || selectedSubCategoryId != null) {
        fetchCategoryFilteredAds();
      } else if (selectedCityId != null || selectedRegionId != null) {
        fetchFilteredAds();
      } else {
        fetchAllAds();
      }
    }
  }

  Future<void> fetchTitleFilteredAds({bool reset = false}) async {
    if (isLoadingAds || !hasMoreAds) return;
    final searchText = _searchController.text.trim();
    if (searchText.isEmpty) return;

    setState(() {
      isLoadingAds = true;
    });

    try {
      final params = <String, String>{
        'title': searchText,
        'page': '$currentPageAds',
        'limit': '$limitAds',
      };

      final uri = Uri.https('sahbo-app-api.onrender.com', '/api/ads/search-by-title', params);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> fetchedAds = decoded['ads'] ?? [];

        setState(() {
          if (reset) allAds.clear();
          allAds.addAll(fetchedAds);
          currentPageAds++;
          isLoadingAds = false;
          if (fetchedAds.length < limitAds) {
            hasMoreAds = false;
          }
        });
      } else {
        setState(() {
          isLoadingAds = false;
          hasMoreAds = false;
        });
        debugPrint('Error fetching title filtered ads: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoadingAds = false;
        hasMoreAds = false;
      });
      debugPrint('Exception fetching title filtered ads: $e');
    }
  }
  String formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays >= 1) return 'منذ ${difference.inDays} يوم';
      if (difference.inHours >= 1) return 'منذ ${difference.inHours} ساعة';
      if (difference.inMinutes >= 1) return 'منذ ${difference.inMinutes} دقيقة';
      return 'الآن';
    } catch (e) {
      return 'غير محدد';
    }
  }

  Widget _buildAdCard(dynamic ad) {
    final List<dynamic> images = ad['images'] is List ? ad['images'] : [];
    final firstImageBase64 = images.isNotEmpty ? images[0] : null;

    final image = firstImageBase64 != null
        ? Image.memory(
      base64Decode(firstImageBase64),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF0FAFA),
                Color(0xFFE8F5F5),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image,
                  size: 40,
                  color: Colors.blue[400],
                ),
                const SizedBox(height: 4),
                Text(
                  'صورة',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    )
        : Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF0F8FF), // Alice blue
              Color(0xFFE6F3FF), // Light blue
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image,
                size: 40,
                color: Colors.blue[400],
              ),
              const SizedBox(height: 4),
              Text(
                'لا توجد صورة',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Color(0xFFF8FBFF), // Very light blue
            Color(0xFFF0F8FF), // Alice blue
          ],
        ),
        border: Border.all(
          color: Colors.blue[300]!,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.blue[300]!.withOpacity(0.2),
          highlightColor: Colors.blue[100]!.withOpacity(0.1),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdDetailsScreen(ad: ad),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: SizedBox(
                    width: double.infinity,
                    child: image,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 80),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(
                          '${ad['adTitle'] ?? ''}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue[300]!,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${ad['price'] ?? '0'} ${ad['currencyName'] ?? ''}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),

                        Text(
                          ad['description'] ?? '',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 12,
                              color: Colors.blue[600],
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                '${ad['cityName'] ?? ''} - ${formatDate(ad['createDate'] ?? '')}',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleProtectedNavigation(BuildContext context, String routeKey) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تسجيل الدخول مطلوب'),
          content: const Text('يجب تسجيل الدخول للوصول إلى هذه الصفحة.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                await prefs.setString('redirect_to', routeKey);
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('تسجيل دخول'),
            ),
          ],
        ),
      );
    } else {
      Widget targetPage;
      switch (routeKey) {
        case 'myAds':
          targetPage = const MyAdsScreen();
          break;
        case 'addAd':
          targetPage = const MultiStepAddAdScreen();
          break;
        default:
          return;
      }
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => targetPage),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking connectivity
    if (isCheckingConnectivity) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show no internet connection screen
    if (!isConnected) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.wifi_off,
                  size: 100,
                  color: Colors.grey,
                ),
                const SizedBox(height: 20),
                const Text(
                  'لا يوجد اتصال بالإنترنت',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _checkInitialConnectivity,
                  child: const Text(
                    'إعادة المحاولة',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Normal home screen when connected
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        drawer: _buildDrawer(context),
        body: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: CustomScrollView(
            controller: _adsScrollController,
            slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              snap: false,
              elevation: 0,
              backgroundColor: Colors.blue[700],
              title: const Text(
                'سوق سوريا',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu,
                      size: 28, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildLocationButton()),
            //SliverToBoxAdapter(child: _buildCategoryFilterSection()),
            SliverToBoxAdapter(child: _buildSearchField()),
            SliverToBoxAdapter(child: ImageSlider()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    'جميع الإعلانات',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E4A47),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 3,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (allAds.isEmpty && isLoadingAds)
                    Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.65,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    if (index == allAds.length && hasMoreAds) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ),
                      );
                    }
                    return _buildAdCard(allAds[index]);
                  },
                  childCount: allAds.length + (hasMoreAds ? 1 : 0),
                ),
              ),
            ),
            if (!hasMoreAds && allAds.isNotEmpty)
              SliverToBoxAdapter(
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Center(
                    child: Text(
                      'لا يوجد المزيد من الإعلانات',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildLocationButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () async {
          await _showLocationFilterDialog();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.blue[300]!, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.blue[200]!.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, size: 22, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  Text(
                    'موقع',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E4A47),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                selectedCity == 'كل المحافظات'
                    ? 'كل المحافظات'
                    : '$selectedCity - $selectedDistrict',
                style: TextStyle(fontSize: 15, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSearchField() {
    return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue[300]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue[200]!.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'ابحث عن منتج أو خدمة...',
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(Icons.search, color: Colors.blue[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SearchResultsScreen(searchText: value.trim()),
              ),
            );
          }
        },
      ),
    ),
  );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue[700]!,
                  Colors.blue[400]!
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _username != null ? 'مرحباً، $_username 👋' : 'مرحبا بك 👋',
                    style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerItem(Icons.home, 'الرئيسية', () {
                  Navigator.pop(context);
                  _reloadHomeScreen();
                }),
                _drawerItem(Icons.list_alt, 'إعلاناتي', () {
                  _handleProtectedNavigation(context, 'myAds');
                }),
                _drawerItem(Icons.add_circle_outline, 'إضافة إعلان', () {
                  _handleProtectedNavigation(context, 'addAd');
                }),
                _drawerItem(Icons.person, 'حسابي', () async {
                  Navigator.pop(context);
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('token');
                  final username = prefs.getString('userName') ?? '';
                  final email = prefs.getString('userEmail') ?? '';

                  if (token == null || token.isEmpty) {
                    await prefs.setString('redirect_to', 'account');
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AccountScreen(
                          isLoggedIn: true,
                          userName: username,
                          userEmail: email, phoneNumber: prefs.getString('userPhone') ?? '',
                        ),
                      ),
                    );
                  }
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[700]),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.grey[800],
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

class ImageSlider extends StatefulWidget {
  const ImageSlider({super.key});

  @override
  State<ImageSlider> createState() => _ImageSliderState();
}

class _ImageSliderState extends State<ImageSlider> {
  final List<String> imagePaths = [
    'assets/image1.jpg',
    'assets/image2.jpg',
    'assets/image3.jpg',
    'assets/image4.jpg',
  ];

  int _currentImageIndex = 0;
  late PageController _pageController;
  Timer? _sliderTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _startAutoSlide();
  }

  @override
  void dispose() {
    _sliderTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _sliderTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageController.hasClients) {
        int nextPage = (_currentImageIndex + 1) % imagePaths.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: imagePaths.length,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[300]!, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue[200]!.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  image: DecorationImage(
                    image: AssetImage(imagePaths[index]),
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                imagePaths.length,
                    (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _currentImageIndex == index ? 20 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentImageIndex == index
                        ? Colors.blue[600]
                        : Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
        ),
    );
  }
}