import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/cv_profile_model.dart';
import '../models/repo_link_model.dart';
import 'storage_service.dart';

class ApiService {
  final StorageService storage;
  final String baseUrl;

  ApiService({
    required this.storage,
    String? customBaseUrl,
  }) : baseUrl = customBaseUrl ?? _determineBaseUrl();

  static String _determineBaseUrl() {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
        return 'http://localhost:8088/api';
      }
      return 'https://sanctuary-backend-u1m1.onrender.com/api';
    }
    // Android emulator host or default local host
    return 'http://localhost:8088/api';
  }

  // --- Health Check ---
  Future<bool> checkHealth() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['status'] == 'ok';
      }
    } catch (_) {}
    return false;
  }

  // --- Auth: Login ---
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['user'] != null) {
          final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
          await storage.setCurrentUser(user);
          return {'success': true, 'user': user, 'source': 'backend'};
        }
      } else if (res.statusCode == 401 || res.statusCode == 400) {
        final data = jsonDecode(res.body);
        return {'success': false, 'message': data['message'] ?? 'Credenciales inválidas'};
      } else {
        debugPrint('Backend API login status ${res.statusCode}, probando credenciales locales...');
      }
    } catch (e) {
      debugPrint('Backend API login error, falling back to local storage: $e');
    }

    // Offline / Local Fallback
    if (storage.verifyLocalCredentials(username, password)) {
      final user = UserModel(username: username, role: username == 'admin' ? 'admin' : 'usuario');
      await storage.setCurrentUser(user);
      return {'success': true, 'user': user, 'source': 'local'};
    }

    return {'success': false, 'message': 'Usuario o contraseña incorrectos'};
  }

  // --- Auth: Register ---
  Future<Map<String, dynamic>> register(
    String username,
    String password, {
    String? email,
    String? confirmPassword,
    String role = 'usuario',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'confirmPassword': confirmPassword ?? password,
          'email': email,
          'role': role,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);
      if (res.statusCode == 201 || res.statusCode == 200) {
        if (data['user'] != null) {
          final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
          await storage.saveLocalUser(user, password);
          await storage.setCurrentUser(user);
          return {'success': true, 'user': user, 'message': data['message']};
        }
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Error al registrar'};
      }
    } catch (e) {
      debugPrint('Backend API register error, saving locally: $e');
    }

    // Save locally fallback
    final user = UserModel(username: username, email: email, role: role);
    await storage.saveLocalUser(user, password);
    await storage.setCurrentUser(user);
    return {'success': true, 'user': user, 'source': 'local'};
  }

  // --- CV Profiles ---
  Future<List<CvProfileModel>> getProfiles() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/cv/profiles')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['profiles'] is List) {
          final list = (data['profiles'] as List)
              .map((e) => CvProfileModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          if (list.isNotEmpty) {
            await storage.saveCvProfiles(list);
            return list;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching profiles from API: $e');
    }
    return storage.getCvProfiles();
  }

  Future<bool> saveProfile(CvProfileModel profile) async {
    // 1. Save locally immediately (autoguardado guarantee)
    final currentList = storage.getCvProfiles();
    final index = currentList.indexWhere((p) => p.id == profile.id);
    if (index >= 0) {
      currentList[index] = profile;
    } else {
      currentList.insert(0, profile);
    }
    await storage.saveCvProfiles(currentList);

    // 2. Sync to Backend in background
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/cv/profiles'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(profile.toJson()),
      ).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Background API sync failed: $e');
      return false;
    }
  }

  Future<bool> deleteProfile(String id) async {
    final currentList = storage.getCvProfiles().where((p) => p.id != id).toList();
    await storage.saveCvProfiles(currentList);

    try {
      final res = await http.delete(Uri.parse('$baseUrl/cv/profiles/$id')).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Sends PDF bytes to the backend on Render for high-fidelity PDF text extraction & OCR
  Future<CvProfileModel?> extractCvPdfOnline(Uint8List bytes, String fileName, CvProfileModel baseProfile) async {
    try {
      final b64 = base64Encode(bytes);
      final res = await http.post(
        Uri.parse('$baseUrl/cv/extract-pdf'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pdfBase64': b64,
          'filename': fileName,
        }),
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data['success'] == true && data['profile'] is Map<String, dynamic>) {
          final profileMap = Map<String, dynamic>.from(data['profile'] as Map);
          profileMap['id'] = baseProfile.id;
          return CvProfileModel.fromJson(profileMap);
        }
      }
    } catch (e) {
      debugPrint('[ApiService] extractCvPdfOnline notice/fallback: $e');
    }
    return null;
  }

  // --- Repo Links ---
  Future<List<RepoLinkModel>> getLinks() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/links')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['links'] is List) {
          final list = (data['links'] as List)
              .map((e) => RepoLinkModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          if (list.isNotEmpty) {
            await storage.saveRepoLinks(list);
            return list;
          }
        }
      }
    } catch (_) {}
    return storage.getRepoLinks();
  }

  Future<bool> addLink(RepoLinkModel link) async {
    final currentList = storage.getRepoLinks()..add(link);
    await storage.saveRepoLinks(currentList);

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/links'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(link.toJson()),
      ).timeout(const Duration(seconds: 3));
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteLink(int id) async {
    final currentList = storage.getRepoLinks().where((l) => l.id != id).toList();
    await storage.saveRepoLinks(currentList);

    try {
      final res = await http.delete(Uri.parse('$baseUrl/links/$id')).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // --- Image Upload (PC upload with local Base64 fallback) ---
  Future<String?> uploadImage(Uint8List bytes, String filename) async {
    final base64Str = 'data:image/png;base64,${base64Encode(bytes)}';
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/upload'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image': base64Str, 'filename': filename}),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['url'] != null) {
          return data['url'] as String;
        }
      }
    } catch (e) {
      debugPrint('API upload failed, using local Base64: $e');
    }
    return base64Str;
  }

  // --- User Profile: Update ---
  Future<Map<String, dynamic>> updateUserProfile(UserModel user, {String? newPassword}) async {
    final payload = {
      'id': user.id,
      'username': user.username,
      'full_name': user.fullName,
      'email': user.email,
      'avatar_url': user.avatarUrl,
      'bio': user.bio,
      if (newPassword != null && newPassword.trim().isNotEmpty) 'password': newPassword.trim(),
    };

    try {
      final res = await http.put(
        Uri.parse('$baseUrl/users/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['user'] != null) {
          final updated = UserModel.fromJson(data['user'] as Map<String, dynamic>);
          await storage.setCurrentUser(updated);
          return {'success': true, 'user': updated, 'message': 'Perfil actualizado correctamente'};
        }
      }
    } catch (e) {
      debugPrint('Backend update user profile failed, falling back to local storage: $e');
    }

    // Local storage fallback
    await storage.setCurrentUser(user);
    return {'success': true, 'user': user, 'message': 'Perfil guardado en almacenamiento local'};
  }

  // --- GitHub Live API Integration ---
  Future<List<Map<String, dynamic>>> fetchGitHubRepos(String username) async {
    final cleanUsername = username.trim().isEmpty ? 'carlosss91' : username.trim();
    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/users/$cleanUsername/repos?sort=updated&per_page=15'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((item) {
          final m = item as Map<String, dynamic>;
          return {
            'name': m['name'] ?? '',
            'full_name': m['full_name'] ?? '',
            'description': m['description'] ?? 'Sin descripción disponible',
            'html_url': m['html_url'] ?? '',
            'language': m['language'] ?? 'Code',
            'stars': m['stargazers_count'] ?? 0,
            'forks': m['forks_count'] ?? 0,
            'updated_at': m['updated_at'] ?? '',
            'topics': (m['topics'] as List?)?.map((e) => e.toString()).toList() ?? [],
          };
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching GitHub repos: $e');
    }

    // Fallback sample repos for carlosss91 / offline demo
    return [
      {
        'name': 'Sanctuary',
        'full_name': '$cleanUsername/Sanctuary',
        'description': 'Plataforma integral web con creador de CV, maquetador A4 y microservicios Docker.',
        'html_url': 'https://github.com/$cleanUsername/Sanctuary',
        'language': 'Dart',
        'stars': 12,
        'forks': 3,
        'updated_at': '2026-09-22',
        'topics': ['flutter', 'docker', 'cv-builder', 'postgresql'],
      },
      {
        'name': 'PortalDocente2.0',
        'full_name': '$cleanUsername/PortalDocente2.0',
        'description': 'Herramienta de gestión pedagógica, tutorías y seguimiento curricular para docentes.',
        'html_url': 'https://github.com/$cleanUsername',
        'language': 'JavaScript',
        'stars': 8,
        'forks': 2,
        'updated_at': '2026-09-18',
        'topics': ['education', 'vue', 'nodejs'],
      },
      {
        'name': 'Odysseus-Workspace',
        'full_name': '$cleanUsername/Odysseus-Workspace',
        'description': 'Entorno de desarrollo ágil y orquestación con IA para microservicios.',
        'html_url': 'https://github.com/$cleanUsername',
        'language': 'Python',
        'stars': 15,
        'forks': 4,
        'updated_at': '2026-09-15',
        'topics': ['python', 'ai-agents', 'docker'],
      },
      {
        'name': 'Trayectoria-Curriculum',
        'full_name': '$cleanUsername/Trayectoria-Curriculum',
        'description': 'Generador de perfiles profesionales en formatos ejecutivos de alta fidelidad.',
        'html_url': 'https://github.com/$cleanUsername',
        'language': 'Dart',
        'stars': 6,
        'forks': 1,
        'updated_at': '2026-09-10',
        'topics': ['cv', 'pdf', 'docx'],
      },
    ];
  }

  // ===========================================================================
  // ADMIN PANEL METHODS
  // ===========================================================================

  Future<List<UserModel>> getAdminUsers() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/admin/users')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['users'] is List) {
          final users = (data['users'] as List)
              .map((u) => UserModel.fromJson(Map<String, dynamic>.from(u as Map)))
              .toList();
          return users;
        }
      }
    } catch (e) {
      debugPrint('Error fetching admin users from backend: $e');
    }
    // Local fallback
    return storage.getLocalUsers();
  }

  Future<Map<String, dynamic>> createAdminUser({
    required String username,
    required String password,
    String? confirmPassword,
    required String role,
    String? fullName,
    String? email,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/admin/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'confirmPassword': confirmPassword ?? password,
          'role': role,
          'full_name': fullName,
          'email': email,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(res.body);
      if (res.statusCode == 201 || res.statusCode == 200) {
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        await storage.saveLocalUser(user, password);
        return {'success': true, 'user': user, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Error al crear usuario'};
      }
    } catch (e) {
      debugPrint('Error creating admin user on backend, saving locally: $e');
      final newUser = UserModel(
        id: DateTime.now().millisecondsSinceEpoch,
        username: username,
        role: role,
        fullName: fullName ?? username,
        email: email,
      );
      await storage.saveLocalUser(newUser, password);
      return {'success': true, 'user': newUser, 'message': 'Usuario guardado en almacenamiento local'};
    }
  }

  Future<Map<String, dynamic>> updateAdminUser({
    required dynamic id,
    required String username,
    String? role,
    String? fullName,
    String? email,
    bool? isBanned,
    String? password,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/admin/users/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'role': ?role,
          'full_name': ?fullName,
          'email': ?email,
          'is_banned': ?isBanned,
          if (password != null && password.isNotEmpty) 'password': password,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        if (password != null && password.isNotEmpty) {
          await storage.saveLocalUser(user, password);
        }
        return {'success': true, 'user': user, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Error al actualizar usuario'};
      }
    } catch (e) {
      debugPrint('Error updating user on backend, updating locally: $e');
      final localUsers = storage.getLocalUsers();
      final idx = localUsers.indexWhere((u) => u.id == id || u.username.toLowerCase() == username.toLowerCase());
      if (idx >= 0) {
        final updated = localUsers[idx].copyWith(
          role: role,
          fullName: fullName,
          email: email,
          isBanned: isBanned,
        );
        await storage.saveLocalUser(updated, password ?? 'admin');
        return {'success': true, 'user': updated, 'message': 'Actualizado en almacenamiento local'};
      }
      return {'success': false, 'message': 'No se pudo actualizar el usuario'};
    }
  }

  Future<Map<String, dynamic>> deleteAdminUser(dynamic id, {required String username}) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/admin/users/$id')).timeout(const Duration(seconds: 12));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        await storage.deleteLocalUser(username);
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Error al eliminar usuario'};
      }
    } catch (e) {
      debugPrint('Error deleting user on backend, removing locally: $e');
      await storage.deleteLocalUser(username);
      return {'success': true, 'message': 'Usuario eliminado localmente'};
    }
  }

  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/admin/stats')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching admin stats: $e');
    }
    final localUsers = storage.getLocalUsers();
    final profiles = storage.getCvProfiles();
    return {
      'success': true,
      'database': 'Almacenamiento Local (Modo Respaldo)',
      'total_users': localUsers.length,
      'total_banned': localUsers.where((u) => u.isBanned).length,
      'total_cvs': profiles.length,
      'total_signed_docs': 0,
      'uptime_seconds': 0,
    };
  }

  // --- Auth: Password Recovery ---
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim()}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200,
        'message': data['message'] ?? 'Solicitud procesada',
        'preview_token': data['preview_token'],
        'preview_url': data['preview_url'],
      };
    } catch (e) {
      debugPrint('Error forgotPassword: $e');
      return {'success': false, 'message': 'No se pudo conectar con el servicio de correo: $e'};
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'token': token.trim(),
          'newPassword': newPassword.trim(),
          'confirmPassword': confirmPassword.trim(),
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        // Also update local fallback password if found
        final localUsers = storage.getLocalUsers();
        for (final u in localUsers) {
          if (u.email?.toLowerCase() == email.trim().toLowerCase()) {
            await storage.saveLocalUser(u, newPassword.trim());
          }
        }
        return {'success': true, 'message': data['message'] ?? 'Contraseña restablecida correctamente'};
      }
      return {'success': false, 'message': data['message'] ?? 'Error al restablecer contraseña'};
    } catch (e) {
      debugPrint('Error resetPassword: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // --- Ephemeral Community Chat ---
  Future<List<Map<String, dynamic>>> getChatMessages() async {
    final localMsgs = storage.getChatMessages();

    try {
      final res = await http.get(Uri.parse('$baseUrl/chat/messages')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['messages'] is List) {
          final serverList = (data['messages'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          // Merge server messages with local messages without losing local unsynced today's messages
          final Map<String, Map<String, dynamic>> mergedMap = {};

          // Add local messages
          for (final msg in localMsgs) {
            final key = (msg['id'] ?? msg['timestamp'] ?? msg['created_at'])?.toString() ?? '';
            if (key.isNotEmpty) mergedMap[key] = msg;
          }

          // Add/Update with server messages
          for (final msg in serverList) {
            final key = (msg['id'] ?? msg['timestamp'] ?? msg['created_at'])?.toString() ?? '';
            if (key.isNotEmpty) mergedMap[key] = msg;
          }

          // Filter strictly for today's messages (renew daily at 00:00)
          final mergedList = mergedMap.values.where((m) {
            final ts = m['timestamp'] ?? m['created_at'] ?? m['id'];
            return storage.isMessageFromToday(ts);
          }).toList();

          mergedList.sort((a, b) {
            final tA = a['timestamp'] ?? a['created_at'] ?? a['id'] ?? '';
            final tB = b['timestamp'] ?? b['created_at'] ?? b['id'] ?? '';
            return tA.toString().compareTo(tB.toString());
          });

          await storage.saveChatMessages(mergedList);
          return mergedList;
        }
      }
    } catch (e) {
      debugPrint('Syncing chat with backend failed (using local): $e');
    }
    return localMsgs;
  }

  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    required String username,
    required String role,
    String? avatarUrl,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    final localMsg = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'username': username,
      'role': role,
      'message': message,
      'text': message,
      'avatarUrl': avatarUrl,
      'avatar_url': avatarUrl,
      'timestamp': nowIso,
      'created_at': nowIso,
    };

    // 1. Immediately persist locally (instant UI response)
    await storage.addChatMessage(localMsg);

    // 2. Try sending to backend
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/chat/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'text': message,
          'username': username,
          'role': role,
          'avatarUrl': avatarUrl,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && (data['chat_message'] != null || data['message'] != null)) {
          return {'success': true, 'message': data['chat_message'] ?? data['message']};
        }
      }
    } catch (e) {
      debugPrint('Syncing sent message to backend failed (kept locally): $e');
    }

    return {'success': true, 'message': localMsg};
  }

  Future<bool> deleteSingleChatMessage(dynamic id) async {
    await storage.deleteChatMessage(id);
    try {
      final res = await http.delete(Uri.parse('$baseUrl/chat/messages/$id')).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting single message on backend: $e');
    }
    return true;
  }

  Future<Map<String, dynamic>> banUserByUsername(String username) async {
    final cleanUser = username.trim();
    if (cleanUser.toLowerCase() == 'admin') {
      return {'success': false, 'message': 'No es posible banear al administrador principal'};
    }

    // Ban in local storage if present
    final localUsers = storage.getLocalUsers();
    final idx = localUsers.indexWhere((u) => u.username.toLowerCase() == cleanUser.toLowerCase());
    if (idx >= 0) {
      final updated = localUsers[idx].copyWith(isBanned: true);
      await storage.saveLocalUser(updated, 'admin');
    }

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/admin/users/ban'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': cleanUser}),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return {'success': true, 'message': data['message'] ?? 'Usuario suspendido'};
      } else {
        final data = jsonDecode(res.body);
        return {'success': false, 'message': data['message'] ?? 'Error al banear usuario'};
      }
    } catch (e) {
      debugPrint('Error banning user on backend: $e');
    }

    return {'success': true, 'message': 'Usuario @$cleanUser suspendido y baneado correctamente'};
  }

  Future<bool> clearChatMessages() async {
    await storage.clearChatMessages();
    try {
      await http.delete(Uri.parse('$baseUrl/chat/messages')).timeout(const Duration(seconds: 4));
    } catch (_) {}
    return true;
  }

  // --- Real SMTP Email Verification Test ---
  Future<Map<String, dynamic>> testSmtp(String targetEmail) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/admin/email/test'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'to': targetEmail, 'targetEmail': targetEmail}),
      ).timeout(const Duration(seconds: 15));

      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error testing SMTP: $e');
      return {'success': false, 'message': 'Error al contactar con el servicio SMTP: $e'};
    }
  }

  // --- Check SMTP Configuration Status ---
  Future<Map<String, dynamic>> getEmailStatus() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/admin/email/status')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {
      'success': true,
      'isConfigured': false,
      'mode': 'simulated',
      'message': 'Modo simulado activo: Las credenciales SMTP no están definidas.',
    };
  }

  // --- Storage & Quota Analytics ---
  Future<Map<String, dynamic>> getStorageAnalytics() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/admin/storage')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting storage analytics: $e');
    }
    return {'success': false, 'message': 'No se pudo obtener analíticas de almacenamiento'};
  }
}


