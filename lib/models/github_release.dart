class GithubRelease {
  final String tagName;
  final String name;
  final String body;
  final String? downloadUrl;
  final String htmlUrl;

  GithubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    this.downloadUrl,
    required this.htmlUrl,
  });

  factory GithubRelease.fromJson(Map<String, dynamic> json) {
    String? downloadUrl;
    if (json['assets'] != null && (json['assets'] as List).isNotEmpty) {
      final assets = json['assets'] as List;
      // On cherche le premier fichier se terminant par .exe
      for (var asset in assets) {
        if (asset['name'].toString().toLowerCase().endsWith('.exe')) {
          downloadUrl = asset['browser_download_url'];
          break;
        }
      }
    }

    return GithubRelease(
      tagName: json['tag_name'] ?? '',
      name: json['name'] ?? '',
      body: json['body'] ?? '',
      downloadUrl: downloadUrl,
      htmlUrl: json['html_url'] ?? '',
    );
  }
  
  bool isNewerThan(String currentVersion) {
    // Nettoyer les chaînes pour ne garder que les chiffres et les points
    String cleanRemote = tagName.replaceAll(RegExp(r'[^0-9.]'), '');
    String cleanCurrent = currentVersion.replaceAll(RegExp(r'[^0-9.]'), '');
    
    List<String> remoteParts = cleanRemote.split('.');
    List<String> currentParts = cleanCurrent.split('.');
    
    for (int i = 0; i < remoteParts.length && i < currentParts.length; i++) {
      int remote = int.tryParse(remoteParts[i]) ?? 0;
      int current = int.tryParse(currentParts[i]) ?? 0;
      if (remote > current) return true;
      if (remote < current) return false;
    }
    return remoteParts.length > currentParts.length;
  }
}
