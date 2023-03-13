import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cron/cron.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

/*
Future<void> main() async {
  runApp(HomePage());
}
*/

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Position? currentLocation;
  _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    currentLocation = await Geolocator.getCurrentPosition();
    print(
        "Current Postion ${currentLocation!.latitude}...........${currentLocation!.longitude}");
  }

  dynamic timeDate = [];
  int index = 0;
  Cron? cron;
  getCoren() async {
    cron = Cron();
    try {
      cron!.schedule(Schedule.parse('*/6 * * * * *'), () {
        _determinePosition();
        Geolocator.getPositionStream().listen((event) {
          print("Current Contius location::$event");
        });
        print(index++);
        setState(() {});
      });
    } on ScheduleParseException {
      print("Exception :$ScheduleParseException");
      // "ScheduleParseException" is thrown if cron parsing is failed.
      await cron!.close();
    }
  }

  @override
  void initState() {
    // _determinePosition();
    // getCoren();
    getLocation();
    // TODO: implement initState
    super.initState();
  }

  getLocation() async {
    Location location = new Location();

    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    LocationData _locationData;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _locationData = await location.getLocation();
    location.enableBackgroundMode(enable: true).then((value) {
      print("${value}");
      print(_locationData);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            FloatingActionButton.extended(
              onPressed: () async {
                getLocation();
                print("Start");
                // setState(() {});
              },
              label: Text("start"),
            ),
            FloatingActionButton.extended(
              onPressed: () async {
                await cron!.close();
                print("Stop Service");
              },
              label: Text("Stop"),
            ),
          ],
        ),
        backgroundColor: Colors.blueGrey,
        body: Center(
          child: Container(
            child: Text("${timeDate}"),
          ),
        ),
      ),
    );
  }
}

Future<void> main() async {
  runApp(const MyApp());
}

Future<void> initializeService() async {
  WidgetsFlutterBinding.ensureInitialized();
  final service = FlutterBackgroundService();

  /// OPTIONAL, using custom notification channel id
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', // id
    'MY FOREGROUND SERVICE', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.low, // importance must be at low or higher level
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isIOS) {
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        // iOS: IOSInitializationSettings(),
        iOS: DarwinInitializationSettings(),
      ),
    );
  }

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // this will be executed when app is in foreground or background in separated isolate
      onStart: onStart,

      // auto start service
      autoStart: false,
      isForegroundMode: true,

      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'AWESOME SERVICE',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      // auto start service
      autoStart: true,

      // this will be executed when app is in foreground in separated isolate
      onForeground: onStart,

      // you have to enable background fetch capability on xcode project
      onBackground: onIosBackground,
    ),
  );

  // service.startService();
}

// to ensure this is executed
// run app from xcode, then from xcode menu, select Simulate Background Fetch

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  final log = preferences.getStringList('log') ?? <String>[];
  log.add(DateTime.now().toIso8601String());
  await preferences.setStringList('log', log);

  return true;
}

Position? currentLocation;
_determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
  }
  currentLocation = await Geolocator.getCurrentPosition();
  print(
      "Current Postion ${currentLocation!.latitude}...........${currentLocation!.longitude}");
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  DartPluginRegistrant.ensureInitialized();

  // For flutter prior to version 3.0.0
  // We have to register the plugin manually

/*
  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setString("hello", "world");
*/

  /// OPTIONAL when use custom notification
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // bring to foreground
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // currentLocation = await Geolocator.getCurrentPosition();
        Geolocator.getPositionStream().listen((event) {
          currentLocation = event;
        });

        /// OPTIONAL for use custom notification
        /// the notification id must be equals with AndroidConfiguration when you call configure() method.
        flutterLocalNotificationsPlugin.show(
          888,
          'Current location only',
          '${currentLocation!.latitude}--${currentLocation!.latitude}',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'my_foreground',
              'MY FOREGROUND SERVICE',
              icon: 'ic_bg_service_small',
              ongoing: true,
            ),
          ),
        );

        // if you don't using custom notification, uncomment this
        // service.setForegroundNotificationInfo(
        //   title: "My App Service",
        //   content: "Updated at ${DateTime.now()}",
        // );
      }
    }

    /// you can see this log in logcat
    print(
        'FLUTTER BACKGROUND SERVICE: ${DateTime.now()} ${currentLocation!.latitude} ${currentLocation!.longitude} ');

    // test using external plugin
    final deviceInfo = DeviceInfoPlugin();
    String? device;
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      device = androidInfo.model;
    }

    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      device = iosInfo.model;
    }

    service.invoke(
      'update',
      {
        "current_date": (currentLocation!.longitude).toString(),
        "device": (currentLocation!.latitude).toString(),
      },
    );
  });
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        {
          print("app in resumed");
          break;
        }
      case AppLifecycleState.inactive: //foreground
        {
          print("app in inactive");
          break;
        }
      case AppLifecycleState.paused:
        print("app in paused");

        break;
      case AppLifecycleState.detached:
        print("app in detached");
        break;
    }
  }

  @override
  initState() {
    // TODO: implement initState
    _determinePosition();
    initializeService();
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String text = "Stop Service";
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Service App'),
        ),
        body: Center(
          child: Column(
            // mainAxisAlignment: MainAxisAlignment.center,

            children: [
              StreamBuilder<Map<String, dynamic>?>(
                stream: FlutterBackgroundService().on('update'),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final data = snapshot.data!;
                  String device = data["device"];
                  String date = data["current_date"];
                  return Column(
                    children: [
                      Text(device),
                      Text(date.toString()),
                    ],
                  );
                },
              ),
              ElevatedButton(
                child: const Text("Foreground Mode"),
                onPressed: () {
                  FlutterBackgroundService().invoke("setAsForeground");
                },
              ),
              ElevatedButton(
                child: const Text("Background Mode"),
                onPressed: () {
                  FlutterBackgroundService().invoke("setAsBackground");
                },
              ),
              ElevatedButton(
                child: Text(text),
                onPressed: () async {
                  final service = FlutterBackgroundService();
                  var isRunning = await service.isRunning();
                  if (isRunning) {
                    service.invoke("stopService");
                  } else {
                    FlutterBackgroundService().invoke("setAsForeground");
                    service.startService();
                  }

                  if (!isRunning) {
                    text = 'Stop Service';
                  } else {
                    text = 'Start Service';
                  }
                  setState(() {});
                },
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.play_arrow),
        ),
      ),
    );
  }
}
