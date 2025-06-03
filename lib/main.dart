import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(BatteryLifeApp());
}

class BatteryLifeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Battery Life Predictor',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF0A0A0A),
        primaryColor: Color(0xFF00D4FF),
      ),
      home: MainNavigationScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    BatteryPredictionScreen(),
    BatteryVisualizationScreen(),
    BatteryAssistantScreen(),
    AnomalyDetectionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: Color(0xFF00D4FF),
          unselectedItemColor: Colors.white60,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.battery_charging_full),
              label: 'Predict',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart),
              label: 'Visualize',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat),
              label: 'Assistant',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.warning),
              label: 'Anomaly',
            ),
          ],
        ),
      ),
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
  final TextEditingController _voltageController = TextEditingController();
  final TextEditingController _currentController = TextEditingController();

  double _temperature = 25.0;
  double? _prediction;
  double? _chargingTime;
  bool _isLoading = false;
  bool _useAdvancedModel = false;
  PlatformFile? _selectedFile;

  final String _baseUrl = 'http://192.168.61.49:5000';

  @override
  void dispose() {
    _dischargeTypeController.dispose();
    _capacityController.dispose();
    _reController.dispose();
    _rctController.dispose();
    _voltageController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  Future<void> _predictBatteryLife() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _prediction = null;
      _chargingTime = null;
    });

    try {
      String endpoint = _useAdvancedModel ? '/predict-lstm' : '/predict';

      final response = await http.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type_discharge': _dischargeTypeController.text.trim(),
          'Capacity': double.parse(_capacityController.text),
          'Re': double.parse(_reController.text),
          'Rct': double.parse(_rctController.text),
          'Temperature': _temperature,
          'Voltage': _voltageController.text.isNotEmpty ? double.parse(_voltageController.text) : null,
          'Current': _currentController.text.isNotEmpty ? double.parse(_currentController.text) : null,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _prediction = data['battery_life_prediction'];
          _chargingTime = data['charging_time_estimate'];
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

  Future<void> _uploadMatFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mat'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
      });

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/upload-mat'),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          _selectedFile!.path!,
        ),
      );

      try {
        var response = await request.send();
        if (response.statusCode == 200) {
          var responseBody = await response.stream.bytesToString();
          var data = jsonDecode(responseBody);

          // Auto-fill the form with extracted data
          setState(() {
            if (data['capacity'] != null) _capacityController.text = data['capacity'].toString();
            if (data['re'] != null) _reController.text = data['re'].toString();
            if (data['rct'] != null) _rctController.text = data['rct'].toString();
            if (data['discharge_type'] != null) _dischargeTypeController.text = data['discharge_type'];
            _prediction = data['prediction'];
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File uploaded and processed successfully!'),
              backgroundColor: Color(0xFF00D4FF),
            ),
          );
        }
      } catch (e) {
        _showErrorDialog('File upload failed: ${e.toString()}');
      }
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
                _buildFileUploadSection(),
                SizedBox(height: 20),
                _buildInputForm(),
                SizedBox(height: 20),
                _buildTemperatureSlider(),
                SizedBox(height: 20),
                _buildModelSelector(),
                SizedBox(height: 30),
                _buildPredictButton(),
                SizedBox(height: 30),
                if (_prediction != null) _buildResultCard(),
                if (_chargingTime != null) _buildChargingTimeCard(),
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
          'Advanced Battery Predictor',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'AI-Powered with Temperature & LSTM',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white60,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFileUploadSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.upload_file,
            color: Color(0xFF00D4FF),
            size: 32,
          ),
          SizedBox(height: 12),
          Text(
            _selectedFile != null ? 'File: ${_selectedFile!.name}' : 'Upload .mat File (Optional)',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _uploadMatFile,
            icon: Icon(Icons.folder_open),
            label: Text('Select .mat File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00D4FF).withOpacity(0.2),
              foregroundColor: Color(0xFF00D4FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputForm() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
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
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _voltageController,
                    label: 'Voltage (V) - Optional',
                    icon: Icons.bolt,
                    hint: 'Current voltage',
                    isRequired: false,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _currentController,
                    label: 'Current (A) - Optional',
                    icon: Icons.electrical_services,
                    hint: 'Charging current',
                    isRequired: false,
                  ),
                ),
              ],
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
    bool isRequired = true,
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
          if (!isRequired && (value == null || value.isEmpty)) return null;
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Please enter $label';
          }
          if (!isString && value!.isNotEmpty && double.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildTemperatureSlider() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.thermostat, color: Color(0xFF00D4FF)),
              SizedBox(width: 12),
              Text(
                'Temperature: ${_temperature.toStringAsFixed(1)}°C',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Color(0xFF00D4FF),
              inactiveTrackColor: Colors.white30,
              thumbColor: Color(0xFF00D4FF),
              overlayColor: Color(0xFF00D4FF).withOpacity(0.3),
            ),
            child: Slider(
              value: _temperature,
              min: -20,
              max: 60,
              divisions: 80,
              onChanged: (value) => setState(() => _temperature = value),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('-20°C', style: TextStyle(color: Colors.white60)),
              Text('60°C', style: TextStyle(color: Colors.white60)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelSelector() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.model_training, color: Color(0xFF00D4FF)),
          SizedBox(width: 12),
          Text(
            'Use Advanced LSTM Model',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          Spacer(),
          Switch(
            value: _useAdvancedModel,
            onChanged: (value) => setState(() => _useAdvancedModel = value),
            activeColor: Color(0xFF00D4FF),
          ),
        ],
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
            'RUL Prediction Result',
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
            'Remaining Useful Life @ ${_temperature.toStringAsFixed(1)}°C',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChargingTimeCard() {
    return Container(
      margin: EdgeInsets.only(top: 20),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF7C3AED).withOpacity(0.1),
            Color(0xFF00D4FF).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(0xFF7C3AED).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.schedule,
            color: Color(0xFF7C3AED),
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'Charging Time Estimate',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Text(
            '${_chargingTime!.toStringAsFixed(1)} hours',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7C3AED),
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Time to Full Charge',
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

class BatteryVisualizationScreen extends StatefulWidget {
  @override
  _BatteryVisualizationScreenState createState() => _BatteryVisualizationScreenState();
}

class _BatteryVisualizationScreenState extends State<BatteryVisualizationScreen> {
  List<FlSpot> _rulData = [];
  List<FlSpot> _capacityData = [];
  bool _isLoading = false;
  final String _baseUrl = 'http://192.168.61.49:5000';

  @override
  void initState() {
    super.initState();
    _loadVisualizationData();
  }

  Future<void> _loadVisualizationData() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(Uri.parse('$_baseUrl/visualization-data'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _rulData = (data['rul_data'] as List)
              .asMap()
              .entries
              .map((entry) => FlSpot(entry.key.toDouble(), entry.value.toDouble()))
              .toList();

          _capacityData = (data['capacity_data'] as List)
              .asMap()
              .entries
              .map((entry) => FlSpot(entry.key.toDouble(), entry.value.toDouble()))
              .toList();
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A0A), Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
              : SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                SizedBox(height: 40),
                _buildRULChart(),
                SizedBox(height: 30),
                _buildCapacityChart(),
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
        Icon(
          Icons.show_chart,
          color: Color(0xFF00D4FF),
          size: 60,
        ),
        SizedBox(height: 16),
        Text(
          'Battery Health Visualization',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'RUL Trends & Capacity Degradation',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  Widget _buildRULChart() {
    return Container(
      height: 300,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remaining Useful Life (RUL) Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: _rulData.isNotEmpty ? _rulData : [FlSpot(0, 0), FlSpot(1, 1)],
                    isCurved: true,
                    color: Color(0xFF00D4FF),
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Color(0xFF00D4FF).withOpacity(0.1),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        'Cycle ${value.toInt()}',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.1),
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.1),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityChart() {
    return Container(
      height: 300,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Capacity Degradation Over Time',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: _capacityData.isNotEmpty ? _capacityData : [FlSpot(0, 100), FlSpot(1, 80)],
                    isCurved: true,
                    color: Color(0xFF7C3AED),
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Color(0xFF7C3AED).withOpacity(0.1),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}%',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        'C${value.toInt()}',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.1),
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.1),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BatteryAssistantScreen extends StatefulWidget {
  @override
  _BatteryAssistantScreenState createState() => _BatteryAssistantScreenState();
}

class _BatteryAssistantScreenState extends State<BatteryAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final String _baseUrl = 'http://192.168.61.49:5000';

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: "Hello! I'm your Battery Assistant. Ask me anything about battery health, degradation, or maintenance tips!",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/battery-assistant'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add(ChatMessage(
            text: data['answer'],
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      } else {
        setState(() {
          _messages.add(ChatMessage(
            text: "Sorry, I couldn't process your request. Please try again.",
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Connection error. Please check your internet connection.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A0A), Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _buildChatArea(),
              ),
              _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.smart_toy,
            color: Color(0xFF00D4FF),
            size: 60,
          ),
          SizedBox(height: 16),
          Text(
            'Battery Assistant',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'AI-Powered Battery Expert',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(16),
        itemCount: _messages.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _messages.length && _isLoading) {
            return _buildTypingIndicator();
          }
          return _buildMessageBubble(_messages[index]);
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) _buildAvatar(false),
          if (!message.isUser) SizedBox(width: 12),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Color(0xFF00D4FF).withOpacity(0.8)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (message.isUser) SizedBox(width: 12),
          if (message.isUser) _buildAvatar(true),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isUser) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isUser
              ? [Color(0xFF7C3AED), Color(0xFF00D4FF)]
              : [Color(0xFF00D4FF), Color(0xFF7C3AED)],
        ),
      ),
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _buildAvatar(false),
          SizedBox(width: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Color(0xFF00D4FF),
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Assistant is typing...',
                  style: TextStyle(
                    color: Colors.white60,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: TextField(
                controller: _messageController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ask about battery health, tips, etc...',
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00D4FF), Color(0xFF7C3AED)],
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => _sendMessage(_messageController.text),
              icon: Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class AnomalyDetectionScreen extends StatefulWidget {
  @override
  _AnomalyDetectionScreenState createState() => _AnomalyDetectionScreenState();
}

class _AnomalyDetectionScreenState extends State<AnomalyDetectionScreen> {
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _reController = TextEditingController();
  final TextEditingController _rctController = TextEditingController();

  bool _isLoading = false;
  bool? _isAnomaly;
  double? _anomalyScore;
  String? _anomalyDetails;
  final String _baseUrl = 'http://192.168.61.49:5000';

  @override
  void dispose() {
    _capacityController.dispose();
    _reController.dispose();
    _rctController.dispose();
    super.dispose();
  }

  Future<void> _detectAnomaly() async {
    if (_capacityController.text.isEmpty ||
        _reController.text.isEmpty ||
        _rctController.text.isEmpty) {
      _showSnackBar('Please fill all fields', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
      _isAnomaly = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/detect-anomaly'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'Capacity': double.parse(_capacityController.text),
          'Re': double.parse(_reController.text),
          'Rct': double.parse(_rctController.text),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isAnomaly = data['is_anomaly'];
          _anomalyScore = data['anomaly_score'];
          _anomalyDetails = data['details'];
        });
      } else {
        _showSnackBar('Failed to detect anomaly', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Connection error: ${e.toString()}', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
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
            colors: [Color(0xFF0A0A0A), Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                SizedBox(height: 40),
                _buildInputForm(),
                SizedBox(height: 30),
                _buildDetectButton(),
                SizedBox(height: 30),
                if (_isAnomaly != null) _buildResultCard(),
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
              colors: [Colors.red, Colors.orange],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            Icons.warning,
            color: Colors.white,
            size: 40,
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Anomaly Detection',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'AI-Powered Battery Health Monitoring',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white60,
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
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Battery Parameters for Analysis',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 24),
          _buildTextField(
            controller: _capacityController,
            label: 'Capacity (Ah)',
            icon: Icons.battery_std,
            hint: 'Enter current battery capacity',
          ),
          SizedBox(height: 20),
          _buildTextField(
            controller: _reController,
            label: 'Re (Ω)',
            icon: Icons.electric_bolt,
            hint: 'Enter electrolyte resistance',
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.orange),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(color: Colors.white70),
          hintStyle: TextStyle(color: Colors.white30),
        ),
      ),
    );
  }

  Widget _buildDetectButton() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red, Colors.orange],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _detectAnomaly,
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
            Icon(Icons.search, size: 24),
            SizedBox(width: 12),
            Text(
              'Detect Anomaly',
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
    Color cardColor = _isAnomaly! ? Colors.red : Colors.green;
    IconData resultIcon = _isAnomaly! ? Icons.error : Icons.check_circle;
    String resultText = _isAnomaly! ? 'ANOMALY DETECTED' : 'NORMAL OPERATION';
    String statusText = _isAnomaly! ? 'Battery shows abnormal behavior' : 'Battery operating normally';

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cardColor.withOpacity(0.1),
            cardColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cardColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            resultIcon,
            color: cardColor,
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            resultText,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cardColor,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 12),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          if (_anomalyScore != null) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Anomaly Score: ${_anomalyScore!.toStringAsFixed(3)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
          if (_anomalyDetails != null) ...[
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text(
                _anomalyDetails!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}