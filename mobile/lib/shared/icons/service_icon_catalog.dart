import 'package:flutter/material.dart';

class ServiceIconOption {
  const ServiceIconOption({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    this.assetPath,
  });

  final String key;
  final String label;
  final String description;
  final IconData icon;
  final String? assetPath;
}

const serviceIconOptions = [
  ServiceIconOption(
    key: 'service_default',
    label: 'Servicio',
    description: 'Servicio general o sin categoria especifica',
    icon: Icons.home_repair_service_outlined,
    assetPath: 'assets/icons/services/generico_abc.png',
  ),
  ServiceIconOption(
    key: 'service_school',
    label: 'Escuela',
    description: 'Colegiaturas, reinscripciones y cuotas escolares',
    icon: Icons.school_outlined,
    assetPath: 'assets/icons/services/escuelas.png',
  ),
  ServiceIconOption(
    key: 'service_electricity',
    label: 'Electricidad',
    description: 'Luz y energia electrica',
    icon: Icons.bolt_outlined,
    assetPath: 'assets/icons/services/electricidad.png',
  ),
  ServiceIconOption(
    key: 'service_gas',
    label: 'Gas',
    description: 'Gas natural, estacionario o cilindros programados',
    icon: Icons.local_fire_department_outlined,
    assetPath: 'assets/icons/services/gas.png',
  ),
  ServiceIconOption(
    key: 'service_triple_play',
    label: 'Triple play',
    description: 'Internet, TV y telefono',
    icon: Icons.router_outlined,
    assetPath: 'assets/icons/services/internet_triple_play.png',
  ),
  ServiceIconOption(
    key: 'service_rent',
    label: 'Renta',
    description: 'Renta de casa, oficina, bodega o local',
    icon: Icons.apartment_outlined,
    assetPath: 'assets/icons/services/edificio_departamentos.png',
  ),
  ServiceIconOption(
    key: 'service_maintenance',
    label: 'Mantenimiento',
    description: 'Condominio, fraccionamiento o mantenimiento periodico',
    icon: Icons.construction_outlined,
    assetPath: 'assets/icons/services/servicio_limpia.png',
  ),
  ServiceIconOption(
    key: 'service_insurance',
    label: 'Seguro',
    description: 'Autos, gastos medicos, vida, hogar u otros seguros',
    icon: Icons.health_and_safety_outlined,
    assetPath: 'assets/icons/services/seguros_medicos.png',
  ),
  ServiceIconOption(
    key: 'service_vehicle',
    label: 'Carro/moto',
    description: 'Tenencia, seguro, credito, verificacion o mantenimiento',
    icon: Icons.directions_car_outlined,
    assetPath: 'assets/icons/services/automovil.png',
  ),
  ServiceIconOption(
    key: 'service_motorcycle',
    label: 'Motocicleta',
    description: 'Seguro, credito, verificacion o mantenimiento de moto',
    icon: Icons.two_wheeler_outlined,
    assetPath: 'assets/icons/services/motocicleta.png',
  ),
  ServiceIconOption(
    key: 'service_saas',
    label: 'SaaS',
    description: 'Licencias, software y herramientas de trabajo',
    icon: Icons.cloud_queue_outlined,
    assetPath: 'assets/icons/services/saas.png',
  ),
  ServiceIconOption(
    key: 'service_subscription',
    label: 'Suscripcion',
    description: 'Streaming, membresias y cargos recurrentes digitales',
    icon: Icons.subscriptions_outlined,
    assetPath: 'assets/icons/services/streaming.png',
  ),
  ServiceIconOption(
    key: 'service_tax',
    label: 'Predial/impuesto',
    description: 'Predial, permisos e impuestos periodicos',
    icon: Icons.account_balance_outlined,
    assetPath: 'assets/icons/services/predial.png',
  ),
  ServiceIconOption(
    key: 'service_water',
    label: 'Agua',
    description: 'Servicio de agua potable o saneamiento',
    icon: Icons.water_drop_outlined,
    assetPath: 'assets/icons/services/agua_potable.png',
  ),
  ServiceIconOption(
    key: 'service_phone_fixed',
    label: 'Telefonia fija',
    description: 'Linea fija y servicios de telefonia residencial',
    icon: Icons.phone_outlined,
    assetPath: 'assets/icons/services/telefonia_fija.png',
  ),
  ServiceIconOption(
    key: 'service_phone_mobile',
    label: 'Telefonia movil',
    description: 'Planes moviles, datos y lineas celulares',
    icon: Icons.smartphone_outlined,
    assetPath: 'assets/icons/services/telefonia_movil.png',
  ),
  ServiceIconOption(
    key: 'service_school_bus',
    label: 'Transporte escolar',
    description: 'Rutas, autobus escolar y transporte recurrente',
    icon: Icons.directions_bus_outlined,
    assetPath: 'assets/icons/services/autobus_escolar.png',
  ),
  ServiceIconOption(
    key: 'service_government',
    label: 'Gobierno',
    description: 'Tramites, derechos y servicios gubernamentales',
    icon: Icons.account_balance_outlined,
    assetPath: 'assets/icons/services/servicios_gubernamentales.png',
  ),
  ServiceIconOption(
    key: 'service_autopay',
    label: 'Domiciliado',
    description: 'Servicio con cargo automatico a cuenta o tarjeta',
    icon: Icons.account_balance_wallet_outlined,
    assetPath: 'assets/icons/services/pagos_domiciliados.png',
  ),
  ServiceIconOption(
    key: 'service_invoice',
    label: 'Facturas',
    description: 'Pagos agrupados, facturas o folios periodicos',
    icon: Icons.receipt_long_outlined,
    assetPath: 'assets/icons/services/facturas_pagadas_agrupadas.png',
  ),
  ServiceIconOption(
    key: 'service_numeric',
    label: 'Generico numerico',
    description: 'Servicio identificado principalmente por numero o folio',
    icon: Icons.pin_outlined,
    assetPath: 'assets/icons/services/generico_123.png',
  ),
];

ServiceIconOption serviceIconByKey(String? key) {
  return serviceIconOptions.firstWhere(
    (option) => option.key == key,
    orElse: () => serviceIconOptions.first,
  );
}

class ServiceIconBadge extends StatelessWidget {
  const ServiceIconBadge({required this.iconKey, this.size = 42, super.key});

  final String? iconKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final option = serviceIconByKey(iconKey);
    final icon = option.assetPath == null
        ? Icon(option.icon, size: size * 0.52)
        : Image.asset(
            option.assetPath!,
            width: size * 0.58,
            height: size * 0.58,
            fit: BoxFit.contain,
          );
    return Tooltip(
      message: option.label,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        child: icon,
      ),
    );
  }
}
