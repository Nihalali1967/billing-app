class ApiConfig {
  // Change this based on your development setup:
  // - For Android emulator: http://10.0.2.2:8000/api
  // - For iOS simulator: http://localhost:8000/api  
  // - For physical device: http://YOUR_COMPUTER_IP:8000/api
  // - For web/desktop: http://localhost:8000/api
  static const String baseUrl = 'https://zynexsolution.in/api';
  // static const String baseUrl = 'http://172.20.10.2:8000/api'; 
  static const Duration timeout = Duration(seconds: 30);
}
