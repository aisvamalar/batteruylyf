/*import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(BatteryLifeApp());
}

class BatteryLifeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Battery Life Predictor',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF0A0A0A),
        primaryColor: Color(0xFF00D4FF),
      ),
      home: BatteryPredictionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BatteryPredictionScreen extends StatefulWidget {
  @override
  _BatteryPredictionScreenState createState() => _BatteryPredictionScreenState();
}

class _BatteryPredictionScreenState extends State<BatteryPredictionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dischargeTypeController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _reController = TextEditingController();
  final TextEditingController _rctController = TextEditingController();

  double? _prediction;
  bool _isLoading = false;

  // Replace with your actual Flask server IP
  final String _baseUrl = 'http://192.168.137.235:5000'; // Update this IP

  @override
  void dispose() {
    _dischargeTypeController.dispose();
    _capacityController.dispose();
    _reController.dispose();
    _rctController.dispose();
    super.dispose();
  }

  Future<void> _predictBatteryLife() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _prediction = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type_discharge': _dischargeTypeController.text.trim(),
          'Capacity': double.parse(_capacityController.text),
          'Re': double.parse(_reController.text),
          'Rct': double.parse(_rctController.text),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _prediction = data['battery_life_prediction'];
        });
      } else {
        _showErrorDialog('Failed to get prediction. Server responded with: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('Connection error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(0xFF1A1A1A),
        title: Text('Error', style: TextStyle(color: Colors.red)),
        content: Text(message, style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK', style: TextStyle(color: Color(0xFF00D4FF))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0A0A),
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                SizedBox(height: 40),
                _buildInputForm(),
                SizedBox(height: 30),
                _buildPredictButton(),
                SizedBox(height: 30),
                if (_prediction != null) _buildResultCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF00D4FF), Color(0xFF7C3AED)],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF00D4FF).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            Icons.battery_charging_full,
            color: Colors.white,
            size: 40,
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Battery Life Predictor',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'AI-Powered Battery Analysis',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white60,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInputForm() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Battery Parameters',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 24),
            _buildTextField(
              controller: _dischargeTypeController,
              label: 'Discharge Type',
              icon: Icons.power,
              hint: 'Enter discharge type (e.g., CC, CCCV, CV)',
              isString: true,
            ),
            SizedBox(height: 20),
            _buildTextField(
              controller: _capacityController,
              label: 'Capacity (Ah)',
              icon: Icons.battery_std,
              hint: 'Enter battery capacity',
            ),
            SizedBox(height: 20),
            _buildTextField(
              controller: _reController,
              label: 'Re (Ω)',
              icon: Icons.electric_bolt,
              hint: 'Enter resistance value',
            ),
            SizedBox(height: 20),
            _buildTextField(
              controller: _rctController,
              label: 'Rct (Ω)',
              icon: Icons.settings_input_component,
              hint: 'Enter charge transfer resistance',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    bool isString = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isString ? TextInputType.text : TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Color(0xFF00D4FF)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(color: Colors.white70),
          hintStyle: TextStyle(color: Colors.white30),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          if (!isString && double.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPredictButton() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00D4FF), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF00D4FF).withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _predictBatteryLife,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isLoading
            ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology, size: 24),
            SizedBox(width: 12),
            Text(
              'Predict Battery Life',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF00D4FF).withOpacity(0.1),
            Color(0xFF7C3AED).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(0xFF00D4FF).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF00D4FF).withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle,
            color: Color(0xFF00D4FF),
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'Prediction Result',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Text(
            '${_prediction!.toStringAsFixed(2)} cycles',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00D4FF),
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Estimated Battery Life',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}

 */