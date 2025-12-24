import 'package:flutter/foundation.dart';

/// Define la estructura de datos para cada entrada de país, incluyendo
/// métodos para serialización de y hacia la base de datos.
@immutable
class CountryData {
  final int? id; // ID de la DB, opcional.
  final String name; // Nombre del país en inglés (ej. 'Spain')
  final String flagEmoji; // Emoji de la bandera (ej. '🇪🇸')

  // 🟢 CORRECCIÓN CLAVE: Cambiado a List<String>
  final List<String> phoneCode; // Códigos de marcación telefónica (ej. ['+34'])

  final List<String> icaoPrefixes;

  // ⭐️ NUEVO CAMPO: Prefijos de Matrícula (ej. ['EC', 'EM'])
  final List<String> registration;

  final String localCurrency; // Código de la moneda local (ej. 'EUR')
  final String currencyName; // Nombre de la moneda en inglés (ej. 'Euro')
  final String
      authorityOfficialName; // Nombre oficial de la autoridad de aviación
  final String authorityAcronym; // Acrónimo de la autoridad

  const CountryData({
    this.id,
    required this.name,
    required this.flagEmoji,
    required this.phoneCode, // Ahora espera List<String>
    required this.icaoPrefixes,
    required this.registration, // ⭐️ REQUERIDO EN CONSTRUCTOR
    required this.localCurrency,
    required this.currencyName,
    required this.authorityOfficialName,
    required this.authorityAcronym,
  });

  // Factory constructor para leer desde la DB (String -> List<String>)
  factory CountryData.fromMap(Map<String, dynamic> map) {
    // Convierte el String de la DB a List<String> para el modelo Dart.
    final icaoString = map['icaoPrefixes'] as String? ?? '';
    final icaoList = icaoString.isEmpty
        ? <String>[]
        : icaoString.split(',').map((s) => s.trim()).toList();

    // ⭐️ NUEVA LÓGICA: Deserialización de registration (String -> List<String>)
    final registrationString = map['registration'] as String? ?? '';
    final registrationList = registrationString.isEmpty
        ? <String>[]
        : registrationString.split(',').map((s) => s.trim()).toList();

    // 🟢 NUEVA LÓGICA: Deserialización de phoneCode (String -> List<String>)
    final phoneCodeString = map['phoneCode'] as String? ?? '';
    final phoneCodeList = phoneCodeString.isEmpty
        ? <String>[]
        : phoneCodeString.split(',').map((s) => s.trim()).toList();

    return CountryData(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      flagEmoji: map['flagEmoji'] as String? ?? '',
      phoneCode: phoneCodeList, // ⬅️ Usar la lista
      icaoPrefixes: icaoList,
      registration: registrationList, // ⭐️ Usar la lista
      localCurrency: map['localCurrency'] as String? ?? '',
      currencyName: map['currencyName'] as String? ?? '',
      authorityOfficialName: map['authorityOfficialName'] as String? ?? '',
      authorityAcronym: map['authorityAcronym'] as String? ?? '',
    );
  }

  // Método para guardar en la DB (List<String> -> String)
  Map<String, Object?> toMap() {
    // Convierte la lista icaoPrefixes a un String separado por comas para la DB.
    final icaoString = icaoPrefixes.join(', ');

    // ⭐️ NUEVA LÓGICA: Serialización de registration (List<String> -> String)
    final registrationString = registration.join(', ');

    // 🟢 NUEVA LÓGICA: Serialización de phoneCode (List<String> -> String)
    final phoneCodeString = phoneCode.join(', ');

    return {
      'id': id,
      'name': name,
      'flagEmoji': flagEmoji,
      'phoneCode': phoneCodeString, // ⬅️ Guardado como String en la DB.
      'icaoPrefixes': icaoString, // Guardado como String en la DB.
      'registration': registrationString, // ⭐️ Guardado como String en la DB.
      'localCurrency': localCurrency,
      'currencyName': currencyName,
      'authorityOfficialName': authorityOfficialName,
      'authorityAcronym': authorityAcronym,
    };
  }
}

// =================================================================
// 🟢 CORRECCIÓN PARA ERRORES DE REFERENCIA (1 y 3)
// Se asume que estas variables son TOP-LEVEL en este archivo.
// Debes asegurarte de llenar estas listas con tus datos reales.
// =================================================================

/// Lista principal de datos de países (DEBE estar definida aquí o en un archivo visible)
const List<CountryData> allCountryData = [
  CountryData(
    name: 'Simulator',
    flagEmoji: '🕹️',
    phoneCode: [''],
    icaoPrefixes: ['SIM'],
    registration: ['SIM'], // ⭐️ CAMPO AGREGADO
    localCurrency: '',
    currencyName: '',
    authorityOfficialName: '',
    authorityAcronym: '',
  ),
  CountryData(
    name: 'Afghanistan',
    flagEmoji: '🇦🇫',
    phoneCode: ['+93'],
    icaoPrefixes: ['OA'],
    registration: ['YA-'], // ⭐️ CAMPO AGREGADO CON VALOR REAL
    localCurrency: 'AFN',
    currencyName: 'Afghan Afghani',
    authorityOfficialName: 'Afghanistan Civil Aviation Authority',
    authorityAcronym: 'ACAA',
  ),
  CountryData(
    name: 'Albania',
    flagEmoji: '🇦🇱',
    phoneCode: ['+355'],
    icaoPrefixes: ['LA'],
    registration: ['ZA-'], // ⭐️ CAMPO AGREGADO CON VALOR REAL
    localCurrency: 'ALL',
    currencyName: 'Albanian Lek',
    authorityOfficialName: 'Autoriteti i Aviacionit Civil',
    authorityAcronym: 'AAC',
  ),
  CountryData(
    name: 'Algeria',
    flagEmoji: '🇩🇿',
    phoneCode: ['+213'],
    icaoPrefixes: ['DA'],
    registration: ['7T-'], // ⭐️ AGREGADO
    localCurrency: 'DZD',
    currencyName: 'Algerian Dinar',
    authorityOfficialName: 'Établissement National de la Navigation Aérienne',
    authorityAcronym: 'ENNA',
  ),
  CountryData(
    name: 'Angola',
    flagEmoji: '🇦🇴',
    phoneCode: ['+244'],
    icaoPrefixes: ['FN'],
    registration: ['D2-'], // ⭐️ AGREGADO
    localCurrency: 'AOA',
    currencyName: 'Angolan Kwanza',
    authorityOfficialName: 'Autoridade Nacional da Aviação Civil',
    authorityAcronym: 'ANAC',
  ),
  CountryData(
    name: 'Anguilla',
    flagEmoji: '🇦🇮',
    phoneCode: ['+1264'],
    icaoPrefixes: ['TQ'],
    registration: ['VP-A'], // ⭐️ AGREGADO
    localCurrency: 'XCD',
    currencyName: 'East Caribbean Dollar',
    authorityOfficialName: 'Anguilla Air and Sea Ports Authority',
    authorityAcronym: 'ASPA',
  ),
  CountryData(
    name: 'Antigua and Barbuda',
    flagEmoji: '🇦🇬',
    phoneCode: ['+1268'],
    icaoPrefixes: ['TA'],
    registration: ['V2-'], // ⭐️ AGREGADO
    localCurrency: 'XCD',
    currencyName: 'East Caribbean Dollar',
    authorityOfficialName: 'Eastern Caribbean Civil Aviation Authority',
    authorityAcronym: 'ECCAA',
  ),
  CountryData(
    name: 'Argentina',
    flagEmoji: '🇦🇷',
    phoneCode: ['+54'],
    icaoPrefixes: ['SA'],
    registration: ['LV-', 'LQ-'], // ⭐️ AGREGADO
    localCurrency: 'ARS',
    currencyName: 'Argentine Peso',
    authorityOfficialName: 'Administración Nacional de Aviación Civil',
    authorityAcronym: 'ANAC',
  ),
  CountryData(
    name: 'Armenia',
    flagEmoji: '🇦🇲',
    phoneCode: ['+374'],
    icaoPrefixes: ['UG'],
    registration: ['EK-'], // ⭐️ AGREGADO
    localCurrency: 'AMD',
    currencyName: 'Armenian Dram',
    authorityOfficialName: 'Civil Aviation Committee',
    authorityAcronym: 'CAC',
  ),
  CountryData(
    name: 'Aruba',
    flagEmoji: '🇦🇼',
    phoneCode: ['+297'],
    icaoPrefixes: ['TQ'],
    registration: ['P4-'], // ⭐️ AGREGADO
    localCurrency: 'AWG',
    currencyName: 'Aruban Florin',
    authorityOfficialName: 'Aruba Civil Aviation Authority',
    authorityAcronym: 'DCA',
  ),
  CountryData(
    name: 'Ascension Island and Saint Helena',
    flagEmoji: '🇸🇭',
    phoneCode: ['+290'],
    icaoPrefixes: ['FH'],
    registration: ['VP-S'], // ⭐️ AGREGADO (Parte del prefijo de Santa Elena)
    localCurrency: 'SHP',
    currencyName: 'Saint Helena Pound',
    authorityOfficialName: 'St Helena Civil Aviation',
    authorityAcronym: 'SCA',
  ),
  CountryData(
    name: 'Australia',
    flagEmoji: '🇦🇺',
    phoneCode: ['+61'],
    icaoPrefixes: ['Y'],
    registration: ['VH-'], // ⭐️ AGREGADO
    localCurrency: 'AUD',
    currencyName: 'Australian Dollar',
    authorityOfficialName: 'Civil Aviation Safety Authority',
    authorityAcronym: 'CASA',
  ),
  CountryData(
    name: 'Austria',
    flagEmoji: '🇦🇹',
    phoneCode: ['+43'],
    icaoPrefixes: ['LO'],
    registration: ['OE-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Austro Control',
    authorityAcronym: 'AC',
  ),
  CountryData(
    name: 'Azerbaijan',
    flagEmoji: '🇦🇿',
    phoneCode: ['+994'],
    icaoPrefixes: ['UB'],
    registration: ['4K-'], // ⭐️ AGREGADO
    localCurrency: 'AZN',
    currencyName: 'Azerbaijani Manat',
    authorityOfficialName: 'State Civil Aviation Agency',
    authorityAcronym: 'SCAA',
  ),
  CountryData(
    name: 'Bahamas',
    flagEmoji: '🇧🇸',
    phoneCode: ['+1242'],
    icaoPrefixes: ['MY'],
    registration: ['C6-'], // ⭐️ AGREGADO
    localCurrency: 'BSD',
    currencyName: 'Bahamian Dollar',
    authorityOfficialName: 'Bahamas Civil Aviation Authority',
    authorityAcronym: 'BCAA',
  ),
  CountryData(
    name: 'Bahrain',
    flagEmoji: '🇧🇭',
    phoneCode: ['+973'],
    icaoPrefixes: ['OB'],
    registration: ['A9C-'], // ⭐️ AGREGADO
    localCurrency: 'BHD',
    currencyName: 'Bahraini Dinar',
    authorityOfficialName: 'Civil Aviation Affairs',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'Bangladesh',
    flagEmoji: '🇧🇩',
    phoneCode: ['+880'],
    icaoPrefixes: ['VG'],
    registration: ['S2-'], // ⭐️ AGREGADO
    localCurrency: 'BDT',
    currencyName: 'Bangladeshi Taka',
    authorityOfficialName: 'Civil Aviation Authority of Bangladesh',
    authorityAcronym: 'CAAB',
  ),
  CountryData(
    name: 'Barbados',
    flagEmoji: '🇧🇧',
    phoneCode: ['+1246'],
    icaoPrefixes: ['TB'],
    registration: ['8P-'], // ⭐️ AGREGADO
    localCurrency: 'BBD',
    currencyName: 'Barbadian Dollar',
    authorityOfficialName: 'Civil Aviation Department',
    authorityAcronym: 'CAD',
  ),
  CountryData(
    name: 'Belarus',
    flagEmoji: '🇧🇾',
    phoneCode: ['+375'],
    icaoPrefixes: ['UM'],
    registration: ['EW-'], // ⭐️ AGREGADO
    localCurrency: 'BYN',
    currencyName: 'Belarusian Ruble',
    authorityOfficialName: 'Department of Aviation, Ministry of Transport',
    authorityAcronym: 'DATM',
  ),
  CountryData(
    name: 'Belgium',
    flagEmoji: '🇧🇪',
    phoneCode: ['+32'],
    icaoPrefixes: ['EB'],
    registration: ['OO-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Directorate General Air Transport',
    authorityAcronym: 'DGAT',
  ),
  CountryData(
    name: 'Belize',
    flagEmoji: '🇧🇿',
    phoneCode: ['+501'],
    icaoPrefixes: ['MZ'],
    registration: ['V3-'], // ⭐️ AGREGADO
    localCurrency: 'BZD',
    currencyName: 'Belize Dollar',
    authorityOfficialName: 'Belize Civil Aviation Department',
    authorityAcronym: 'BCAD',
  ),
  CountryData(
    name: 'Benin',
    flagEmoji: '🇧🇯',
    phoneCode: ['+229'],
    icaoPrefixes: ['DB'],
    registration: ['TY-'], // ⭐️ AGREGADO
    localCurrency: 'XOF',
    currencyName: 'West African CFA Franc',
    authorityOfficialName: 'Agence Nationale de l\'Aviation Civile',
    authorityAcronym: 'ANAC',
  ),
  CountryData(
    name: 'Bermuda',
    flagEmoji: '🇧🇲',
    phoneCode: ['+1441'],
    icaoPrefixes: ['TX'],
    registration: ['VP-B', 'VQ-B'], // ⭐️ AGREGADO
    localCurrency: 'BMD',
    currencyName: 'Bermudian Dollar',
    authorityOfficialName: 'Bermuda Civil Aviation Authority',
    authorityAcronym: 'BCAA',
  ),
  CountryData(
    name: 'Bhutan',
    flagEmoji: '🇧🇹',
    phoneCode: ['+975'],
    icaoPrefixes: ['VQ'],
    registration: ['A5-'], // ⭐️ AGREGADO
    localCurrency: 'BTN',
    currencyName: 'Bhutanese Ngultrum',
    authorityOfficialName: 'Department of Air Transport',
    authorityAcronym: 'DAT',
  ),
  CountryData(
    name: 'Bolivia',
    flagEmoji: '🇧🇴',
    phoneCode: ['+591'],
    icaoPrefixes: ['SL'],
    registration: ['CP-'], // ⭐️ AGREGADO
    localCurrency: 'BOB',
    currencyName: 'Bolivian Boliviano',
    authorityOfficialName: 'Dirección General de Aeronáutica Civil',
    authorityAcronym: 'DGAC',
  ),
  CountryData(
    name: 'Bosnia and Herzegovina',
    flagEmoji: '🇧🇦',
    phoneCode: ['+387'],
    icaoPrefixes: ['LQ'],
    registration: ['E7-'], // ⭐️ AGREGADO
    localCurrency: 'BAM',
    currencyName: 'Bosnia-Herzegovina Convertible Mark',
    authorityOfficialName: 'Directorate of Civil Aviation',
    authorityAcronym: 'BHDCA',
  ),
  CountryData(
    name: 'Botswana',
    flagEmoji: '🇧🇼',
    phoneCode: ['+267'],
    icaoPrefixes: ['FB'],
    registration: ['A2-'], // ⭐️ AGREGADO
    localCurrency: 'BWP',
    currencyName: 'Botswana Pula',
    authorityOfficialName: 'Civil Aviation Authority of Botswana',
    authorityAcronym: 'CAAB',
  ),
  CountryData(
    name: 'Brazil',
    flagEmoji: '🇧🇷',
    phoneCode: ['+55'],
    icaoPrefixes: ['SB', 'SD', 'SN', 'SS', 'SW'],
    registration: ['PP-', 'PR-', 'PS-', 'PT-'], // ⭐️ AGREGADO
    localCurrency: 'BRL',
    currencyName: 'Brazilian Real',
    authorityOfficialName: 'Agência Nacional de Aviação Civil',
    authorityAcronym: 'ANAC',
  ),
  CountryData(
    name: 'British Indian Ocean Territory',
    flagEmoji: '🇮🇴',
    phoneCode: ['+246'],
    icaoPrefixes: ['FJ'],
    registration: ['VQ-B'], // ⭐️ AGREGADO
    localCurrency: 'USD',
    currencyName: 'US Dollar',
    authorityOfficialName: 'British Indian Ocean Territory Administration',
    authorityAcronym: 'BIOTA',
  ),
  CountryData(
    name: 'British Virgin Islands',
    flagEmoji: '🇻🇬',
    phoneCode: ['+1284'],
    icaoPrefixes: ['TU'],
    registration: ['VP-L'], // ⭐️ AGREGADO
    localCurrency: 'USD',
    currencyName: 'US Dollar',
    authorityOfficialName: 'BVI Civil Aviation Authority',
    authorityAcronym: 'BVICAA',
  ),
  CountryData(
    name: 'Brunei',
    flagEmoji: '🇧🇳',
    phoneCode: ['+673'],
    icaoPrefixes: ['WB'],
    registration: ['V8-'], // ⭐️ AGREGADO
    localCurrency: 'BND',
    currencyName: 'Brunei Dollar',
    authorityOfficialName: 'Department of Civil Aviation',
    authorityAcronym: 'DCA',
  ),
  CountryData(
    name: 'Bulgaria',
    flagEmoji: '🇧🇬',
    phoneCode: ['+359'],
    icaoPrefixes: ['LB'],
    registration: ['LZ-'], // ⭐️ AGREGADO
    localCurrency: 'BGN',
    currencyName: 'Bulgarian Lev',
    authorityOfficialName: 'Civil Aviation Administration',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'Burkina Faso',
    flagEmoji: '🇧🇫',
    phoneCode: ['+226'],
    icaoPrefixes: ['DF'],
    registration: ['XT-'], // ⭐️ AGREGADO
    localCurrency: 'XOF',
    currencyName: 'West African CFA Franc',
    authorityOfficialName: 'Agence Nationale de l\'Aviation Civile',
    authorityAcronym: 'ANAC',
  ),
  CountryData(
    name: 'Burundi',
    flagEmoji: '🇧🇮',
    phoneCode: ['+257'],
    icaoPrefixes: ['HB'],
    registration: ['9U-'], // ⭐️ AGREGADO
    localCurrency: 'BIF',
    currencyName: 'Burundian Franc',
    authorityOfficialName: 'Autorité de l\'Aviation Civile du Burundi',
    authorityAcronym: 'AACB',
  ),
  CountryData(
    name: 'Cambodia',
    flagEmoji: '🇰🇭',
    phoneCode: ['+855'],
    icaoPrefixes: ['VD'],
    registration: ['XU-'], // ⭐️ AGREGADO
    localCurrency: 'KHR',
    currencyName: 'Cambodian Riel',
    authorityOfficialName: 'State Secretariat of Civil Aviation',
    authorityAcronym: 'SSCA',
  ),
  CountryData(
    name: 'Cameroon',
    flagEmoji: '🇨🇲',
    phoneCode: ['+237'],
    icaoPrefixes: ['FK'],
    registration: ['TJ-'], // ⭐️ AGREGADO
    localCurrency: 'XAF',
    currencyName: 'Central African CFA Franc',
    authorityOfficialName: 'Cameroon Civil Aviation Authority',
    authorityAcronym: 'CCAA',
  ),
  CountryData(
    name: 'Canada',
    flagEmoji: '🇨🇦',
    phoneCode: [
      '+1368',
      '+1403',
      '+1587',
      '+1780',
      '+1825',
      '+1236',
      '+1250',
      '+1604',
      '+1672',
      '+1778',
      '+1782',
      '+1902',
      '+1204',
      '+1431',
      '+1584',
      '+1782',
      '+1902',
      '+1506',
      '+1867',
      '+1226',
      '+1249',
      '+1289',
      '+1343',
      '+1365',
      '+1416',
      '+1437',
      '+1519',
      '+1548',
      '+1613',
      '+1647',
      '+1683',
      '+1705',
      '+1742',
      '+1753',
      '+1807',
      '+1905',
      '+1263',
      '+1354',
      '+1367',
      '+1418',
      '+1438',
      '+1468',
      '+1450',
      '+1514',
      '+1581',
      '+1579',
      '+1819',
      '+1873',
      '+1306',
      '+1474',
      '+1639',
      '+1709',
      '+1867',
      '+1867'
    ],
    icaoPrefixes: ['C'],
    registration: ['C-', 'CF-'], // ⭐️ AGREGADO
    localCurrency: 'CAD',
    currencyName: 'Canadian Dollar',
    authorityOfficialName: 'Transport Canada Civil Aviation',
    authorityAcronym: 'TCCA',
  ),
  CountryData(
    name: 'Cape Verde',
    flagEmoji: '🇨🇻',
    phoneCode: ['+238'],
    icaoPrefixes: ['GV'],
    registration: ['D4-'], // ⭐️ AGREGADO
    localCurrency: 'CVE',
    currencyName: 'Cape Verdean Escudo',
    authorityOfficialName: 'Agência de Aviação Civil',
    authorityAcronym: 'AAC',
  ),
  CountryData(
    name: 'Cayman Islands',
    flagEmoji: '🇰🇾',
    phoneCode: ['+1345'],
    icaoPrefixes: ['MW'],
    registration: ['VP-C', 'VQ-C'], // ⭐️ AGREGADO
    localCurrency: 'KYD',
    currencyName: 'Cayman Islands Dollar',
    authorityOfficialName: 'Civil Aviation Authority of the Cayman Islands',
    authorityAcronym: 'CAACI',
  ),
  CountryData(
    name: 'Central African Republic',
    flagEmoji: '🇨🇫',
    phoneCode: ['+236'],
    icaoPrefixes: ['FE'],
    registration: ['TL-'], // ⭐️ AGREGADO
    localCurrency: 'XAF',
    currencyName: 'Central African CFA Franc',
    authorityOfficialName: 'Agence Nationale de l\'Aviation Civile',
    authorityAcronym: 'ANAC',
  ),
  CountryData(
    name: 'Chad',
    flagEmoji: '🇹🇩',
    phoneCode: ['+235'],
    icaoPrefixes: ['FT'],
    registration: ['TT-'], // ⭐️ AGREGADO
    localCurrency: 'XAF',
    currencyName: 'Central African CFA Franc',
    authorityOfficialName: 'Agence Nationale de l\'Aviation Civile',
    authorityAcronym: 'ANAC',
  ),
  CountryData(
    name: 'Chile',
    flagEmoji: '🇨🇱',
    phoneCode: ['+56'],
    icaoPrefixes: ['SC', 'SH'],
    registration: ['CC-'], // ⭐️ AGREGADO
    localCurrency: 'CLP',
    currencyName: 'Chilean Peso',
    authorityOfficialName: 'Dirección General de Aeronáutica Civil',
    authorityAcronym: 'DGAC',
  ),
  CountryData(
    name: 'China',
    flagEmoji: '🇨🇳',
    phoneCode: ['+86'],
    icaoPrefixes: ['Z'],
    registration: ['B-'], // ⭐️ AGREGADO
    localCurrency: 'CNY',
    currencyName: 'Chinese Yuan',
    authorityOfficialName: 'Civil Aviation Administration of China',
    authorityAcronym: 'CAAC',
  ),
  CountryData(
    name: 'Colombia',
    flagEmoji: '🇨🇴',
    phoneCode: ['+57'],
    icaoPrefixes: ['SK'],
    registration: ['HK-', 'HJ-'], // ⭐️ AGREGADO
    localCurrency: 'COP',
    currencyName: 'Colombian Peso',
    authorityOfficialName:
        'Unidad Administrativa Especial de Aeronáutica Civil',
    authorityAcronym: 'UAEAC',
  ),
  CountryData(
    name: 'Comoros',
    flagEmoji: '🇰🇲',
    phoneCode: ['+269'],
    icaoPrefixes: ['FM'],
    registration: ['D6-'], // ⭐️ AGREGADO
    localCurrency: 'KMF',
    currencyName: 'Comorian Franc',
    authorityOfficialName:
        'Agence Nationale de l\'Aviation Civile et de la Météorologie',
    authorityAcronym: 'ANACM',
  ),
  CountryData(
    name: 'Cook Islands',
    flagEmoji: '🇨🇰',
    phoneCode: ['+682'],
    icaoPrefixes: ['NC'],
    registration: ['E5-'], // ⭐️ AGREGADO
    localCurrency: 'NZD',
    currencyName: 'New Zealand Dollar',
    authorityOfficialName: 'Ministry of Transport',
    authorityAcronym: 'MOT',
  ),
  CountryData(
    name: 'Costa Rica',
    flagEmoji: '🇨🇷',
    phoneCode: ['+506'],
    icaoPrefixes: ['MR'],
    registration: ['TI-'], // ⭐️ AGREGADO
    localCurrency: 'CRC',
    currencyName: 'Costa Rican Colón',
    authorityOfficialName: 'Dirección General de Aviación Civil',
    authorityAcronym: 'DGAC',
  ),
  CountryData(
    name: 'Côte d\'Ivoire',
    flagEmoji: '🇨🇮',
    phoneCode: ['+225'],
    icaoPrefixes: ['DI'],
    registration: ['TU-'], // ⭐️ AGREGADO
    localCurrency: 'XOF',
    currencyName: 'West African CFA Franc',
    authorityOfficialName: 'Autorité Nationale de l\'Aviation Civile',
    authorityAcronym: 'ANAC',
  ),
  CountryData(
    name: 'Croatia',
    flagEmoji: '🇭🇷',
    phoneCode: ['+385'],
    icaoPrefixes: ['LD'],
    registration: ['9A-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Croatian Civil Aviation Agency',
    authorityAcronym: 'CCAA',
  ),
  CountryData(
    name: 'Cuba',
    flagEmoji: '🇨🇺',
    phoneCode: ['+53'],
    icaoPrefixes: ['MU'],
    registration: ['CU-'], // ⭐️ AGREGADO
    localCurrency: 'CUP',
    currencyName: 'Cuban Peso',
    authorityOfficialName: 'Instituto de Aeronáutica Civil de Cuba',
    authorityAcronym: 'IACC',
  ),
  CountryData(
    name: 'Cyprus',
    flagEmoji: '🇨🇾',
    phoneCode: ['+357'],
    icaoPrefixes: ['LC'],
    registration: ['5B-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Department of Civil Aviation',
    authorityAcronym: 'DCA',
  ),
  CountryData(
    name: 'Czech Republic',
    flagEmoji: '🇨🇿',
    phoneCode: ['+420'],
    icaoPrefixes: ['LK'],
    registration: ['OK-'], // ⭐️ AGREGADO
    localCurrency: 'CZK',
    currencyName: 'Czech Koruna',
    authorityOfficialName: 'Civil Aviation Authority',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'Democratic Republic of the Congo',
    flagEmoji: '🇨🇩',
    phoneCode: ['+243'],
    icaoPrefixes: ['FZ'],
    registration: ['9Q-', '9T-'], // ⭐️ AGREGADO
    localCurrency: 'CDF',
    currencyName: 'Congolese Franc',
    authorityOfficialName: 'Autorité de l\'Aviation Civile',
    authorityAcronym: 'AAC',
  ),
  CountryData(
    name: 'Denmark',
    flagEmoji: '🇩🇰',
    phoneCode: ['+45'],
    icaoPrefixes: ['EK'],
    registration: ['OY-'], // ⭐️ AGREGADO
    localCurrency: 'DKK',
    currencyName: 'Danish Krone',
    authorityOfficialName: 'Trafikstyrelsen (Danish Civil Aviation Authority)',
    authorityAcronym: 'Trafikstyrelsen',
  ),
  CountryData(
    name: 'Djibouti',
    flagEmoji: '🇩🇯',
    phoneCode: ['+253'],
    icaoPrefixes: ['HD'],
    registration: ['J2-'], // ⭐️ AGREGADO
    localCurrency: 'DJF',
    currencyName: 'Djiboutian Franc',
    authorityOfficialName: 'Autorité de l\'Aviation Civile',
    authorityAcronym: 'AAC',
  ),
  CountryData(
    name: 'Dominica',
    flagEmoji: '🇩🇲',
    phoneCode: ['+1767'],
    icaoPrefixes: ['TD'],
    registration: ['J7-'], // ⭐️ AGREGADO
    localCurrency: 'XCD',
    currencyName: 'East Caribbean Dollar',
    authorityOfficialName: 'Eastern Caribbean Civil Aviation Authority',
    authorityAcronym: 'ECCAA',
  ),
  CountryData(
    name: 'Dominican Republic',
    flagEmoji: '🇩🇴',
    phoneCode: ['+1809'],
    icaoPrefixes: ['MD'],
    registration: ['HI-'], // ⭐️ AGREGADO
    localCurrency: 'DOP',
    currencyName: 'Dominican Peso',
    authorityOfficialName: 'Instituto Dominicano de Aviación Civil',
    authorityAcronym: 'IDAC',
  ),
  CountryData(
    name: 'Ecuador',
    flagEmoji: '🇪🇨',
    phoneCode: ['+593'],
    icaoPrefixes: ['SE'],
    registration: ['HC-'], // ⭐️ AGREGADO
    localCurrency: 'USD',
    currencyName: 'US Dollar',
    authorityOfficialName: 'Dirección General de Aviación Civil',
    authorityAcronym: 'DGAC',
  ),
  CountryData(
    name: 'Egypt',
    flagEmoji: '🇪🇬',
    phoneCode: ['+20'],
    icaoPrefixes: ['HE'],
    registration: ['SU-'], // ⭐️ AGREGADO
    localCurrency: 'EGP',
    currencyName: 'Egyptian Pound',
    authorityOfficialName: 'Egyptian Civil Aviation Authority',
    authorityAcronym: 'ECAA',
  ),
  CountryData(
    name: 'El Salvador',
    flagEmoji: '🇸🇻',
    phoneCode: ['+503'],
    icaoPrefixes: ['MS'],
    registration: ['YS-'], // ⭐️ AGREGADO
    localCurrency: 'USD',
    currencyName: 'US Dollar',
    authorityOfficialName: 'Autoridad de Aviación Civil',
    authorityAcronym: 'AAC',
  ),
  CountryData(
    name: 'Equatorial Guinea',
    flagEmoji: '🇬🇶',
    phoneCode: ['+240'],
    icaoPrefixes: ['FG'],
    registration: ['3C-'], // ⭐️ AGREGADO
    localCurrency: 'XAF',
    currencyName: 'Central African CFA Franc',
    authorityOfficialName: 'Dirección General de Aviación Civil',
    authorityAcronym: 'DGAC',
  ),
  CountryData(
    name: 'Eritrea',
    flagEmoji: '🇪🇷',
    phoneCode: ['+291'],
    icaoPrefixes: ['HH'],
    registration: ['E3-'], // ⭐️ AGREGADO
    localCurrency: 'ERN',
    currencyName: 'Eritrean Nakfa',
    authorityOfficialName: 'Eritrean Civil Aviation Authority',
    authorityAcronym: 'ECAA',
  ),
  CountryData(
    name: 'Estonia',
    flagEmoji: '🇪🇪',
    phoneCode: ['+372'],
    icaoPrefixes: ['EE'],
    registration: ['ES-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Estonian Civil Aviation Administration',
    authorityAcronym: 'ECAA',
  ),
  CountryData(
    name: 'Eswatini (Swaziland)',
    flagEmoji: '🇸🇿',
    phoneCode: ['+268'],
    icaoPrefixes: ['FD'],
    registration: ['3D-', '3DC-'], // ⭐️ AGREGADO
    localCurrency: 'SZL',
    currencyName: 'Swazi Lilangeni',
    authorityOfficialName: 'Eswatini Civil Aviation Authority',
    authorityAcronym: 'ESWACAA',
  ),
  CountryData(
    name: 'Ethiopia',
    flagEmoji: '🇪🇹',
    phoneCode: ['+251'],
    icaoPrefixes: ['HA'],
    registration: ['ET-'], // ⭐️ AGREGADO
    localCurrency: 'ETB',
    currencyName: 'Ethiopian Birr',
    authorityOfficialName: 'Ethiopian Civil Aviation Authority',
    authorityAcronym: 'ECAA',
  ),
  CountryData(
    name: 'Falkland Islands',
    flagEmoji: '🇫🇰',
    phoneCode: ['+500'],
    icaoPrefixes: ['SF'],
    registration: ['VP-F'], // ⭐️ AGREGADO
    localCurrency: 'FKP',
    currencyName: 'Falkland Islands Pound',
    authorityOfficialName: 'Falkland Islands Civil Aviation',
    authorityAcronym: 'FICAA',
  ),
  CountryData(
    name: 'Fiji',
    flagEmoji: '🇫🇯',
    phoneCode: ['+679'],
    icaoPrefixes: ['NF'],
    registration: ['DQ-'], // ⭐️ AGREGADO
    localCurrency: 'FJD',
    currencyName: 'Fijian Dollar',
    authorityOfficialName: 'Civil Aviation Authority of Fiji',
    authorityAcronym: 'CAAF',
  ),
  CountryData(
    name: 'Finland',
    flagEmoji: '🇫🇮',
    phoneCode: ['+358'],
    icaoPrefixes: ['EF'],
    registration: ['OH-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Finnish Transport and Communications Agency',
    authorityAcronym: 'Traficom',
  ),
  CountryData(
    name: 'France',
    flagEmoji: '🇫🇷',
    phoneCode: ['+33'],
    icaoPrefixes: ['LF'],
    registration: ['F-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Direction Générale de l\'Aviation Civile',
    authorityAcronym: 'DGAC',
  ),
  CountryData(
    name: 'French Guiana',
    flagEmoji: '🇬🇫',
    phoneCode: ['+594'],
    icaoPrefixes: ['SO'],
    registration: ['F-O'], // ⭐️ AGREGADO (Prefijo francés)
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Direction Générale de l\'Aviation Civile (DGAC)',
    authorityAcronym: 'DGAC',
  ),
  CountryData(
    name: 'French Polynesia',
    flagEmoji: '🇵🇫',
    phoneCode: ['+689'],
    icaoPrefixes: ['NT'],
    registration: ['F-O'], // ⭐️ AGREGADO
    localCurrency: 'XPF',
    currencyName: 'CFP Franc',
    authorityOfficialName: 'Direction de l\'Aviation Civile',
    authorityAcronym: 'DAC',
  ),
  CountryData(
    name: 'Gabon',
    flagEmoji: '🇬🇦',
    phoneCode: ['+241'],
    icaoPrefixes: ['FO'],
    registration: ['TR-'], // ⭐️ AGREGADO
    localCurrency: 'XAF',
    currencyName: 'Central African CFA Franc',
    authorityOfficialName: 'Agence Nationale de l\'Aviation Civile',
    authorityAcronym: 'ANAC',
  ),
  CountryData(
    name: 'Gambia',
    flagEmoji: '🇬🇲',
    phoneCode: ['+220'],
    icaoPrefixes: ['GB'],
    registration: ['C5-'], // ⭐️ AGREGADO
    localCurrency: 'GMD',
    currencyName: 'Gambian Dalasi',
    authorityOfficialName: 'Gambia Civil Aviation Authority',
    authorityAcronym: 'GCAA',
  ),
  CountryData(
    name: 'Gaza Strip',
    flagEmoji: '🇵🇸',
    phoneCode: ['+970'],
    icaoPrefixes: ['LV'],
    registration: ['SU-G'], // ⭐️ AGREGADO (Registro egipcio para Gaza)
    localCurrency: 'ILS',
    currencyName: 'Israeli New Shekel',
    authorityOfficialName: 'Palestinian Civil Aviation Authority',
    authorityAcronym: 'PCAA',
  ),
  CountryData(
    name: 'Georgia',
    flagEmoji: '🇬🇪',
    phoneCode: ['+995'],
    icaoPrefixes: ['UG'],
    registration: ['4L-'], // ⭐️ AGREGADO
    localCurrency: 'GEL',
    currencyName: 'Georgian Lari',
    authorityOfficialName: 'Georgian Civil Aviation Agency',
    authorityAcronym: 'GCAA',
  ),
  CountryData(
    name: 'Germany',
    flagEmoji: '🇩🇪',
    phoneCode: ['+49'],
    icaoPrefixes: ['ED', 'ET'],
    registration: ['D-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Luftfahrt-Bundesamt',
    authorityAcronym: 'LBA',
  ),
  CountryData(
    name: 'Ghana',
    flagEmoji: '🇬🇭',
    phoneCode: ['+233'],
    icaoPrefixes: ['DG'],
    registration: ['9G'], // ⭐️ AGREGADO
    localCurrency: 'GHS',
    currencyName: 'Ghanaian Cedi',
    authorityOfficialName: 'Ghana Civil Aviation Authority',
    authorityAcronym: 'GCAA',
  ),
  CountryData(
    name: 'Gibraltar',
    flagEmoji: '🇬🇮',
    phoneCode: ['+350'],
    icaoPrefixes: ['LX'],
    registration: ['VP-G'], // ⭐️ AGREGADO (Prefijo británico)
    localCurrency: 'GIP',
    currencyName: 'Gibraltar Pound',
    authorityOfficialName: 'Gibraltar Airport Authority',
    authorityAcronym: 'GAA',
  ),
  CountryData(
    name: 'Greece',
    flagEmoji: '🇬🇷',
    phoneCode: ['+30'],
    icaoPrefixes: ['LG'],
    registration: ['SX-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Hellenic Civil Aviation Authority',
    authorityAcronym: 'HCAA',
  ),
  CountryData(
    name: 'Grenada',
    flagEmoji: '🇬🇩',
    phoneCode: ['+1473'],
    icaoPrefixes: ['TG'],
    registration: ['J3-'], // ⭐️ AGREGADO
    localCurrency: 'XCD',
    currencyName: 'East Caribbean Dollar',
    authorityOfficialName: 'Eastern Caribbean Civil Aviation Authority',
    authorityAcronym: 'ECCAA',
  ),
  CountryData(
    name: 'Greenland',
    flagEmoji: '🇬🇱',
    phoneCode: ['+299'],
    icaoPrefixes: ['BG'],
    registration: ['OY-'], // ⭐️ AGREGADO (Prefijo danés)
    localCurrency: 'DKK',
    currencyName: 'Danish Krone',
    authorityOfficialName: 'Danish Civil Aviation Authority',
    authorityAcronym: 'Trafikstyrelsen',
  ),
  CountryData(
    name: 'Guadeloupe',
    flagEmoji: '🇬🇵',
    phoneCode: ['+590'],
    icaoPrefixes: ['TF'],
    registration: ['F-O'], // ⭐️ AGREGADO (Prefijo francés)
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Direction Générale de l\'Aviation Civile (DGAC)',
    authorityAcronym: 'DGAC',
  ),
  CountryData(
    name: 'Guam, Northern Mariana Islands',
    flagEmoji: '🇬🇺',
    phoneCode: ['+1671'],
    icaoPrefixes: ['PG'],
    registration: ['N'], // ⭐️ AGREGADO (Prefijo estadounidense)
    localCurrency: 'USD',
    currencyName: 'US Dollar',
    authorityOfficialName: 'Federal Aviation Administration',
    authorityAcronym: 'FAA',
  ),
  CountryData(
    name: 'Guatemala',
    flagEmoji: '🇬🇹',
    phoneCode: ['+502'],
    icaoPrefixes: ['MG'],
    registration: ['TG-'], // ⭐️ AGREGADO
    localCurrency: 'GTQ',
    currencyName: 'Guatemalan Quetzal',
    authorityOfficialName: 'Dirección General de Aeronáutica Civil',
    authorityAcronym: 'DGAC',
  ),
  CountryData(
    name: 'Guinea',
    flagEmoji: '🇬🇳',
    phoneCode: ['+224'],
    icaoPrefixes: ['GU'],
    registration: ['3X-'], // ⭐️ AGREGADO
    localCurrency: 'GNF',
    currencyName: 'Guinean Franc',
    authorityOfficialName: 'Direction Nationale de l\'Aviation Civile',
    authorityAcronym: 'DNAC',
  ),
  CountryData(
    name: 'Guinea-Bissau',
    flagEmoji: '🇬🇼',
    phoneCode: ['+245'],
    icaoPrefixes: ['GG'],
    registration: ['J5-'], // ⭐️ AGREGADO
    localCurrency: 'XOF',
    currencyName: 'West African CFA Franc',
    authorityOfficialName: 'Autoridade de Aviação Civil',
    authorityAcronym: 'AAC',
  ),
  CountryData(
    name: 'Guyana',
    flagEmoji: '🇬🇾',
    phoneCode: ['+592'],
    icaoPrefixes: ['SY'],
    registration: ['8R-'], // ⭐️ AGREGADO
    localCurrency: 'GYD',
    currencyName: 'Guyanese Dollar',
    authorityOfficialName: 'Guyana Civil Aviation Authority',
    authorityAcronym: 'GCAA',
  ),
  CountryData(
    name: 'Haiti',
    flagEmoji: '🇭🇹',
    phoneCode: ['+509'],
    icaoPrefixes: ['MT'],
    registration: ['HH-'], // ⭐️ AGREGADO
    localCurrency: 'HTG',
    currencyName: 'Haitian Gourde',
    authorityOfficialName: 'Office National de l\'Aviation Civile',
    authorityAcronym: 'OFNAC',
  ),
  CountryData(
    name: 'Honduras',
    flagEmoji: '🇭🇳',
    phoneCode: ['+504'],
    icaoPrefixes: ['MH'],
    registration: ['HR-'], // ⭐️ AGREGADO
    localCurrency: 'HNL',
    currencyName: 'Honduran Lempira',
    authorityOfficialName: 'Agencia Hondureña de Aeronáutica Civil',
    authorityAcronym: 'AHAC',
  ),
  CountryData(
    name: 'Hong Kong',
    flagEmoji: '🇭🇰',
    phoneCode: ['+852'],
    icaoPrefixes: ['VH'],
    registration: ['B-H', 'B-H', 'B-L'], // ⭐️ AGREGADO
    localCurrency: 'HKD',
    currencyName: 'Hong Kong Dollar',
    authorityOfficialName: 'Civil Aviation Department',
    authorityAcronym: 'CAD',
  ),
  CountryData(
    name: 'Hungary',
    flagEmoji: '🇭🇺',
    phoneCode: ['+36'],
    icaoPrefixes: ['LH'],
    registration: ['HA-'], // ⭐️ AGREGADO
    localCurrency: 'HUF',
    currencyName: 'Hungarian Forint',
    authorityOfficialName: 'National Transport Authority',
    authorityAcronym: 'NTA',
  ),
  CountryData(
    name: 'Iceland',
    flagEmoji: '🇮🇸',
    phoneCode: ['+354'],
    icaoPrefixes: ['BI'],
    registration: ['TF-'], // ⭐️ AGREGADO
    localCurrency: 'ISK',
    currencyName: 'Icelandic Króna',
    authorityOfficialName: 'Icelandic Transport Authority',
    authorityAcronym: 'ICETRA',
  ),
  CountryData(
    name: 'India',
    flagEmoji: '🇮🇳',
    phoneCode: ['+91'],
    icaoPrefixes: ['VA', 'VE', 'VI', 'VO'],
    registration: ['VT-'], // ⭐️ AGREGADO
    localCurrency: 'INR',
    currencyName: 'Indian Rupee',
    authorityOfficialName: 'Directorate General of Civil Aviation',
    authorityAcronym: 'DGCA',
  ),
  CountryData(
    name: 'Indonesia',
    flagEmoji: '🇮🇩',
    phoneCode: ['+62'],
    icaoPrefixes: ['WA', 'WI', 'WQ', 'WR'],
    registration: ['PK-'], // ⭐️ AGREGADO
    localCurrency: 'IDR',
    currencyName: 'Indonesian Rupiah',
    authorityOfficialName: 'Directorate General of Civil Aviation',
    authorityAcronym: 'DGCA',
  ),
  CountryData(
    name: 'Iran',
    flagEmoji: '🇮🇷',
    phoneCode: ['+98'],
    icaoPrefixes: ['OI'],
    registration: ['EP-'], // ⭐️ AGREGADO
    localCurrency: 'IRR',
    currencyName: 'Iranian Rial',
    authorityOfficialName: 'Iran Civil Aviation Organization',
    authorityAcronym: 'CAO.IRI',
  ),
  CountryData(
    name: 'Iraq',
    flagEmoji: '🇮🇶',
    phoneCode: ['+964'],
    icaoPrefixes: ['OR'],
    registration: ['YI-'], // ⭐️ AGREGADO
    localCurrency: 'IQD',
    currencyName: 'Iraqi Dinar',
    authorityOfficialName: 'Iraqi Civil Aviation Authority',
    authorityAcronym: 'ICAA',
  ),
  CountryData(
    name: 'Ireland',
    flagEmoji: '🇮🇪',
    phoneCode: ['+353'],
    icaoPrefixes: ['EI'],
    registration: ['EI-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Irish Aviation Authority',
    authorityAcronym: 'IAA',
  ),
  CountryData(
    name: 'Israel',
    flagEmoji: '🇮🇱',
    phoneCode: ['+972'],
    icaoPrefixes: ['LL'],
    registration: ['4X-', '4Z-'], // ⭐️ AGREGADO
    localCurrency: 'ILS',
    currencyName: 'Israeli New Shekel',
    authorityOfficialName: 'Civil Aviation Authority of Israel',
    authorityAcronym: 'CAAI',
  ),
  CountryData(
    name: 'Italy',
    flagEmoji: '🇮🇹',
    phoneCode: ['+39'],
    icaoPrefixes: ['LI'],
    registration: ['I-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Ente Nazionale per l\'Aviazione Civile',
    authorityAcronym: 'ENAC',
  ),
  CountryData(
    name: 'Jamaica',
    flagEmoji: '🇯🇲',
    phoneCode: ['+1876'],
    icaoPrefixes: ['MK'],
    registration: ['6Y-'],
    localCurrency: 'JMD',
    currencyName: 'Jamaican Dollar',
    authorityOfficialName: 'Jamaica Civil Aviation Authority',
    authorityAcronym: 'JCAA',
  ),
  CountryData(
    name: 'Japan',
    flagEmoji: '🇯🇵',
    phoneCode: ['+81'],
    icaoPrefixes: ['RJ', 'RO'],
    registration: ['JA'], // ⭐️ AGREGADO
    localCurrency: 'JPY',
    currencyName: 'Japanese Yen',
    authorityOfficialName: 'Japan Civil Aviation Bureau',
    authorityAcronym: 'JCAB',
  ),
  CountryData(
    name: 'Jordan',
    flagEmoji: '🇯🇴',
    phoneCode: ['+962'],
    icaoPrefixes: ['OJ'],
    registration: ['JY-'], // ⭐️ AGREGADO
    localCurrency: 'JOD',
    currencyName: 'Jordanian Dinar',
    authorityOfficialName: 'Civil Aviation Regulatory Commission',
    authorityAcronym: 'CARC',
  ),
  CountryData(
    name: 'Kazakhstan',
    flagEmoji: '🇰🇿',
    phoneCode: ['+7'],
    icaoPrefixes: ['UA'],
    registration: ['UP-'], // ⭐️ AGREGADO
    localCurrency: 'KZT',
    currencyName: 'Kazakhstani Tenge',
    authorityOfficialName: 'Civil Aviation Committee',
    authorityAcronym: 'CAC',
  ),
  CountryData(
    name: 'Kenya',
    flagEmoji: '🇰🇪',
    phoneCode: ['+254'],
    icaoPrefixes: ['HK'],
    registration: ['5Y-'], // ⭐️ AGREGADO
    localCurrency: 'KES',
    currencyName: 'Kenyan Shilling',
    authorityOfficialName: 'Kenya Civil Aviation Authority',
    authorityAcronym: 'KCAA',
  ),
  CountryData(
    name: 'Kiribati',
    flagEmoji: '🇰🇮',
    phoneCode: ['+686'],
    icaoPrefixes: ['NG'],
    registration: ['T3-'], // ⭐️ AGREGADO
    localCurrency: 'AUD',
    currencyName: 'Australian Dollar',
    authorityOfficialName: 'Civil Aviation Authority of Kiribati',
    authorityAcronym: 'CAAK',
  ),
  CountryData(
    name: 'Kuwait',
    flagEmoji: '🇰🇼',
    phoneCode: ['+965'],
    icaoPrefixes: ['OK'],
    registration: ['9K-'], // ⭐️ AGREGADO
    localCurrency: 'KWD',
    currencyName: 'Kuwaiti Dinar',
    authorityOfficialName: 'Directorate General of Civil Aviation',
    authorityAcronym: 'DGCA',
  ),
  CountryData(
    name: 'Kyrgyzstan',
    flagEmoji: '🇰🇬',
    phoneCode: ['+996'],
    icaoPrefixes: ['UA'],
    registration: ['EX-'], // ⭐️ AGREGADO
    localCurrency: 'KGS',
    currencyName: 'Kyrgyzstani Som',
    authorityOfficialName: 'Civil Aviation Agency',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'Laos',
    flagEmoji: '🇱🇦',
    phoneCode: ['+856'],
    icaoPrefixes: ['VL'],
    registration: ['RDLP-'], // ⭐️ AGREGADO
    localCurrency: 'LAK',
    currencyName: 'Lao Kip',
    authorityOfficialName: 'Department of Civil Aviation',
    authorityAcronym: 'DCA',
  ),
  CountryData(
    name: 'Latvia',
    flagEmoji: '🇱🇻',
    phoneCode: ['+371'],
    icaoPrefixes: ['EV'],
    registration: ['YL-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Civil Aviation Agency of Latvia',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'Lebanon',
    flagEmoji: '🇱🇧',
    phoneCode: ['+961'],
    icaoPrefixes: ['OL'],
    registration: ['OD-'], // ⭐️ AGREGADO
    localCurrency: 'LBP',
    currencyName: 'Lebanese Pound',
    authorityOfficialName: 'Directorate General of Civil Aviation',
    authorityAcronym: 'DGCA',
  ),
  CountryData(
    name: 'Lesotho',
    flagEmoji: '🇱🇸',
    phoneCode: ['+266'],
    icaoPrefixes: ['FX'],
    registration: ['7P-'], // ⭐️ AGREGADO
    localCurrency: 'LSL',
    currencyName: 'Lesotho Loti',
    authorityOfficialName: 'Department of Civil Aviation',
    authorityAcronym: 'DCA',
  ),
  CountryData(
    name: 'Liberia',
    flagEmoji: '🇱🇷',
    phoneCode: ['+231'],
    icaoPrefixes: ['GL'],
    registration: ['A8-'], // ⭐️ AGREGADO
    localCurrency: 'LRD',
    currencyName: 'Liberian Dollar',
    authorityOfficialName: 'Liberia Civil Aviation Authority',
    authorityAcronym: 'LCAA',
  ),
  CountryData(
    name: 'Libya',
    flagEmoji: '🇱🇾',
    phoneCode: ['+218'],
    icaoPrefixes: ['HL'],
    registration: ['5A-'], // ⭐️ AGREGADO
    localCurrency: 'LYD',
    currencyName: 'Libyan Dinar',
    authorityOfficialName: 'Libyan Civil Aviation Authority',
    authorityAcronym: 'LCAA',
  ),
  CountryData(
    name: 'Liechtenstein',
    flagEmoji: '🇱🇮',
    phoneCode: ['+423'],
    icaoPrefixes: ['LS'],
    registration: ['HB-'], // Usa el registro suizo. ⭐️ AGREGADO
    localCurrency: 'CHF',
    currencyName: 'Swiss Franc',
    authorityOfficialName: 'Federal Office of Civil Aviation (Switzerland)',
    authorityAcronym: 'FOCA',
  ),
  CountryData(
    name: 'Lithuania',
    flagEmoji: '🇱🇹',
    phoneCode: ['+370'],
    icaoPrefixes: ['EY'],
    registration: ['LY-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Civil Aviation Administration',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'Luxembourg',
    flagEmoji: '🇱🇺',
    phoneCode: ['+352'],
    icaoPrefixes: ['EL'],
    registration: ['LX-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Directorate of Civil Aviation',
    authorityAcronym: 'DAC',
  ),
  CountryData(
    name: 'Macau',
    flagEmoji: '🇲🇴',
    phoneCode: ['+853'],
    icaoPrefixes: ['VM'],
    registration: ['B-M'], // ⭐️ AGREGADO
    localCurrency: 'MOP',
    currencyName: 'Macanese Pataca',
    authorityOfficialName: 'Civil Aviation Authority of Macau',
    authorityAcronym: 'AACM',
  ),
  CountryData(
    name: 'Madagascar',
    flagEmoji: '🇲🇬',
    phoneCode: ['+261'],
    icaoPrefixes: ['FM'],
    registration: ['5R-'], // ⭐️ AGREGADO
    localCurrency: 'MGA',
    currencyName: 'Malagasy Ariary',
    authorityOfficialName: 'Aviation Civile de Madagascar',
    authorityAcronym: 'ACM',
  ),
  CountryData(
    name: 'Malawi',
    flagEmoji: '🇲🇼',
    phoneCode: ['+265'],
    icaoPrefixes: ['FW'],
    registration: ['7Q-'], // ⭐️ AGREGADO
    localCurrency: 'MWK',
    currencyName: 'Malawian Kwacha',
    authorityOfficialName: 'Department of Civil Aviation',
    authorityAcronym: 'DCA',
  ),
  CountryData(
    name: 'Malaysia',
    flagEmoji: '🇲🇾',
    phoneCode: ['+60'],
    icaoPrefixes: ['WM'],
    registration: ['9M-'], // ⭐️ AGREGADO
    localCurrency: 'MYR',
    currencyName: 'Malaysian Ringgit',
    authorityOfficialName: 'Civil Aviation Authority of Malaysia',
    authorityAcronym: 'CAAM',
  ),
  CountryData(
    name: 'Maldives',
    flagEmoji: '🇲🇻',
    phoneCode: ['+960'],
    icaoPrefixes: ['VR'],
    registration: ['8Q-'], // ⭐️ AGREGADO
    localCurrency: 'MVR',
    currencyName: 'Maldivian Rufiyaa',
    authorityOfficialName: 'Maldives Civil Aviation Authority',
    authorityAcronym: 'MCAA',
  ),
  CountryData(
    name: 'Mali',
    flagEmoji: '🇲🇱',
    phoneCode: ['+223'],
    icaoPrefixes: ['GA'],
    registration: ['TZ-'], // ⭐️ AGREGADO
    localCurrency: 'XOF',
    currencyName: 'West African CFA Franc',
    authorityOfficialName: 'Agence Nationale de l\'Aviation Civile',
    authorityAcronym: 'ANAC',
  ),
  CountryData(
    name: 'Malta',
    flagEmoji: '🇲🇹',
    phoneCode: ['+356'],
    icaoPrefixes: ['LM'],
    registration: ['9H-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Transport Malta Civil Aviation Directorate',
    authorityAcronym: 'TM-CAD',
  ),
  CountryData(
    name: 'Marshall Islands',
    flagEmoji: '🇲🇭',
    phoneCode: ['+692'],
    icaoPrefixes: ['PK'],
    registration: ['V7-'], // ⭐️ AGREGADO
    localCurrency: 'USD',
    currencyName: 'US Dollar',
    authorityOfficialName: 'Marshall Islands Civil Aviation',
    authorityAcronym: 'MICA',
  ),
  CountryData(
    name: 'Martinique',
    flagEmoji: '🇲🇶',
    phoneCode: ['+596'],
    icaoPrefixes: ['TL'],
    registration: ['F-O'], // ⭐️ AGREGADO (Prefijo francés)
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Direction Générale de l\'Aviation Civile (DGAC)',
    authorityAcronym: 'DGAC',
  ),
  CountryData(
    name: 'Mauritania',
    flagEmoji: '🇲🇷',
    phoneCode: ['+222'],
    icaoPrefixes: ['GQ'],
    registration: ['5T-'], // ⭐️ AGREGADO
    localCurrency: 'MRU',
    currencyName: 'Mauritanian Ouguiya',
    authorityOfficialName: 'Agence Nationale de l\'Aviation Civile',
    authorityAcronym: 'ANAC',
  ),
  CountryData(
    name: 'Mauritius',
    flagEmoji: '🇲🇺',
    phoneCode: ['+230'],
    icaoPrefixes: ['FIM'],
    registration: ['3B-'], // ⭐️ AGREGADO
    localCurrency: 'MUR',
    currencyName: 'Mauritian Rupee',
    authorityOfficialName: 'Department of Civil Aviation',
    authorityAcronym: 'DCA',
  ),
  CountryData(
    name: 'Mexico',
    flagEmoji: '🇲🇽',
    phoneCode: ['+52'],
    icaoPrefixes: ['MM'],
    registration: ['XA', 'XB', 'XC'], // ⭐️ AGREGADO
    localCurrency: 'MXN',
    currencyName: 'Mexican Peso',
    authorityOfficialName: 'Agencia Federal de Aviación Civil',
    authorityAcronym: 'AFAC',
  ),
  CountryData(
    name: 'Micronesia',
    flagEmoji: '🇫🇲',
    phoneCode: ['+691'],
    icaoPrefixes: ['PT'],
    registration: ['V6-'], // ⭐️ AGREGADO
    localCurrency: 'USD',
    currencyName: 'US Dollar',
    authorityOfficialName:
        'Department of Transportation, Communications & Infrastructure',
    authorityAcronym: 'DTC&I',
  ),
  CountryData(
    name: 'Moldova',
    flagEmoji: '🇲🇩',
    phoneCode: ['+373'],
    icaoPrefixes: ['LU'],
    registration: ['ER-'], // ⭐️ AGREGADO
    localCurrency: 'MDL',
    currencyName: 'Moldovan Leu',
    authorityOfficialName: 'Civil Aviation Authority of Moldova',
    authorityAcronym: 'AAC',
  ),
  CountryData(
    name: 'Monaco',
    flagEmoji: '🇲🇨',
    phoneCode: ['+377'],
    icaoPrefixes: ['LN'],
    registration: ['3A-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Direction de l\'Aviation Civile (France)',
    authorityAcronym: 'DAC',
  ),
  CountryData(
    name: 'Mongolia',
    flagEmoji: '🇲🇳',
    phoneCode: ['+976'],
    icaoPrefixes: ['ZM'],
    registration: ['JU-'], // ⭐️ AGREGADO
    localCurrency: 'MNT',
    currencyName: 'Mongolian Tögrög',
    authorityOfficialName: 'Civil Aviation Authority of Mongolia',
    authorityAcronym: 'MCAA',
  ),
  CountryData(
    name: 'Montenegro',
    flagEmoji: '🇲🇪',
    phoneCode: ['+382'],
    icaoPrefixes: ['LY'],
    registration: ['4O-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Civil Aviation Agency of Montenegro',
    authorityAcronym: 'ACV',
  ),
  CountryData(
    name: 'Montserrat',
    flagEmoji: '🇲🇸',
    phoneCode: ['+1664'],
    icaoPrefixes: ['TR'],
    registration: ['VP-M'], // ⭐️ AGREGADO
    localCurrency: 'XCD',
    currencyName: 'East Caribbean Dollar',
    authorityOfficialName: 'Eastern Caribbean Civil Aviation Authority',
    authorityAcronym: 'ECCAA',
  ),
  CountryData(
    name: 'Morocco',
    flagEmoji: '🇲🇦',
    phoneCode: ['+212'],
    icaoPrefixes: ['GM'],
    registration: ['CN-'], // ⭐️ AGREGADO
    localCurrency: 'MAD',
    currencyName: 'Moroccan Dirham',
    authorityOfficialName: 'Direction Générale de l\'Aviation Civile',
    authorityAcronym: 'DGAC',
  ),
  CountryData(
    name: 'Mozambique',
    flagEmoji: '🇲🇿',
    phoneCode: ['+258'],
    icaoPrefixes: ['FQ'],
    registration: ['C9-'], // ⭐️ AGREGADO
    localCurrency: 'MZN',
    currencyName: 'Mozambican Metical',
    authorityOfficialName: 'Instituto de Aviação Civil de Moçambique',
    authorityAcronym: 'IACM',
  ),
  CountryData(
    name: 'Myanmar',
    flagEmoji: '🇲🇲',
    phoneCode: ['+95'],
    icaoPrefixes: ['VY'],
    registration: ['XY', 'XZ'], // ⭐️ AGREGADO
    localCurrency: 'MMK',
    currencyName: 'Burmese Kyat',
    authorityOfficialName: 'Department of Civil Aviation',
    authorityAcronym: 'DCA',
  ),
  CountryData(
    name: 'Namibia',
    flagEmoji: '🇳🇦',
    phoneCode: ['+264'],
    icaoPrefixes: ['FY'],
    registration: ['V5-'], // ⭐️ AGREGADO
    localCurrency: 'NAD',
    currencyName: 'Namibian Dollar',
    authorityOfficialName: 'Namibia Civil Aviation Authority',
    authorityAcronym: 'NCAA',
  ),
  CountryData(
    name: 'Nauru',
    flagEmoji: '🇳🇷',
    phoneCode: ['+674'],
    icaoPrefixes: ['AN'],
    registration: ['C2-'], // ⭐️ AGREGADO
    localCurrency: 'AUD',
    currencyName: 'Australian Dollar',
    authorityOfficialName: 'Nauru Civil Aviation Authority',
    authorityAcronym: 'NCAA',
  ),
  CountryData(
    name: 'Nepal',
    flagEmoji: '🇳🇵',
    phoneCode: ['+977'],
    icaoPrefixes: ['VN'],
    registration: ['9N-'], // ⭐️ AGREGADO
    localCurrency: 'NPR',
    currencyName: 'Nepalese Rupee',
    authorityOfficialName: 'Civil Aviation Authority of Nepal',
    authorityAcronym: 'CAAN',
  ),
  CountryData(
    name: 'Netherlands',
    flagEmoji: '🇳🇱',
    phoneCode: ['+31'],
    icaoPrefixes: ['EH'],
    registration: ['PH-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Inspectie Leefomgeving en Transport (ILT)',
    authorityAcronym: 'ILT',
  ),
  CountryData(
    name: 'New Caledonia',
    flagEmoji: '🇳🇨',
    phoneCode: ['+687'],
    icaoPrefixes: ['NW'],
    registration: ['F-O'], // ⭐️ AGREGADO (Prefijo francés)
    localCurrency: 'XPF',
    currencyName: 'CFP Franc',
    authorityOfficialName: 'Direction de l\'Aviation Civile',
    authorityAcronym: 'DAC',
  ),
  CountryData(
    name: 'New Zealand',
    flagEmoji: '🇳🇿',
    phoneCode: ['+64'],
    icaoPrefixes: ['NZ'],
    registration: ['ZK-', 'ZL-', 'ZM-'],
    localCurrency: 'NZD',
    currencyName: 'New Zealand Dollar',
    authorityOfficialName: 'Civil Aviation Authority of New Zealand',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'Nicaragua',
    flagEmoji: '🇳🇮',
    phoneCode: ['+505'],
    icaoPrefixes: ['MN'],
    registration: ['YN-'], // ⭐️ AGREGADO
    localCurrency: 'NIO',
    currencyName: 'Nicaraguan Córdoba',
    authorityOfficialName: 'Instituto Nicaragüense de Aeronáutica Civil',
    authorityAcronym: 'INAC',
  ),
  CountryData(
    name: 'Niger',
    flagEmoji: '🇳🇪',
    phoneCode: ['+227'],
    icaoPrefixes: ['DR'],
    registration: ['5U-'], // ⭐️ AGREGADO
    localCurrency: 'XOF',
    currencyName: 'West African CFA Franc',
    authorityOfficialName: 'Agence Nationale de l\'Aviation Civile',
    authorityAcronym: 'ANAC',
  ),
  CountryData(
    name: 'Nigeria',
    flagEmoji: '🇳🇬',
    phoneCode: ['+234'],
    icaoPrefixes: ['DN'],
    registration: ['5N-'], // ⭐️ AGREGADO
    localCurrency: 'NGN',
    currencyName: 'Nigerian Naira',
    authorityOfficialName: 'Nigerian Civil Aviation Authority',
    authorityAcronym: 'NCAA',
  ),
  CountryData(
    name: 'Niue',
    flagEmoji: '🇳🇺',
    phoneCode: ['+683'],
    icaoPrefixes: ['NI'],
    registration: ['ZK-N'], // ⭐️ AGREGADO (Registro neozelandés)
    localCurrency: 'NZD',
    currencyName: 'New Zealand Dollar',
    authorityOfficialName: 'Civil Aviation Authority of New Zealand (de facto)',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'North Korea',
    flagEmoji: '🇰🇵',
    phoneCode: ['+850'],
    icaoPrefixes: ['ZK'],
    registration: ['P-'], // ⭐️ AGREGADO
    localCurrency: 'KPW',
    currencyName: 'North Korean Won',
    authorityOfficialName: 'Civil Aviation Administration of DPRK',
    authorityAcronym: 'CAADPRK',
  ),
  CountryData(
    name: 'North Macedonia',
    flagEmoji: '🇲🇰',
    phoneCode: ['+389'],
    icaoPrefixes: ['LW'],
    registration: ['Z3-'], // ⭐️ AGREGADO
    localCurrency: 'MKD',
    currencyName: 'Macedonian Denar',
    authorityOfficialName: 'Civil Aviation Agency',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'Norway',
    flagEmoji: '🇳🇴',
    phoneCode: ['+47'],
    icaoPrefixes: ['EN'],
    registration: ['LN-'], // ⭐️ AGREGADO
    localCurrency: 'NOK',
    currencyName: 'Norwegian Krone',
    authorityOfficialName: 'Luftfartstilsynet (Civil Aviation Authority)',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'Oman',
    flagEmoji: '🇴🇲',
    phoneCode: ['+968'],
    icaoPrefixes: ['OO'],
    registration: ['A4O-'], // ⭐️ AGREGADO
    localCurrency: 'OMR',
    currencyName: 'Omani Rial',
    authorityOfficialName: 'Civil Aviation Authority',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'Pakistan',
    flagEmoji: '🇵🇰',
    phoneCode: ['+92'],
    icaoPrefixes: ['OP'],
    registration: ['AP-'], // ⭐️ AGREGADO
    localCurrency: 'PKR',
    currencyName: 'Pakistani Rupee',
    authorityOfficialName: 'Pakistan Civil Aviation Authority',
    authorityAcronym: 'PCAA',
  ),
  CountryData(
    name: 'Palau',
    flagEmoji: '🇵🇼',
    phoneCode: ['+680'],
    icaoPrefixes: ['PT'],
    registration: ['N'], // ⭐️ AGREGADO (Registro estadounidense)
    localCurrency: 'USD',
    currencyName: 'US Dollar',
    authorityOfficialName: 'Federal Aviation Administration (de facto)',
    authorityAcronym: 'FAA',
  ),
  CountryData(
    name: 'Palestine (West Bank and Gaza)',
    flagEmoji: '🇵🇸',
    phoneCode: ['+970'],
    icaoPrefixes: ['LV'],
    registration: ['SU-G'], // ⭐️ AGREGADO (Registro egipcio para Gaza)
    localCurrency: 'ILS',
    currencyName: 'Israeli New Shekel',
    authorityOfficialName: 'Palestinian Civil Aviation Authority',
    authorityAcronym: 'PCAA',
  ),
  CountryData(
    name: 'Panama',
    flagEmoji: '🇵🇦',
    phoneCode: ['+507'],
    icaoPrefixes: ['MP'],
    registration: ['HP-'], // ⭐️ AGREGADO
    localCurrency: 'USD',
    currencyName: 'US Dollar/Panamanian Balboa',
    authorityOfficialName: 'Autoridad Aeronáutica Civil',
    authorityAcronym: 'AAC',
  ),
  CountryData(
    name: 'Papua New Guinea',
    flagEmoji: '🇵🇬',
    phoneCode: ['+675'],
    icaoPrefixes: ['PG'],
    registration: ['P2-'], // ⭐️ AGREGADO
    localCurrency: 'PGK',
    currencyName: 'Papua New Guinean Kina',
    authorityOfficialName: 'Civil Aviation Safety Authority PNG',
    authorityAcronym: 'CASA PNG',
  ),
  CountryData(
    name: 'Paraguay',
    flagEmoji: '🇵🇾',
    phoneCode: ['+595'],
    icaoPrefixes: ['SG'],
    registration: ['ZP-'], // ⭐️ AGREGADO
    localCurrency: 'PYG',
    currencyName: 'Paraguayan Guaraní',
    authorityOfficialName: 'Dirección Nacional de Aeronáutica Civil',
    authorityAcronym: 'DINAC',
  ),
  CountryData(
    name: 'Peru',
    flagEmoji: '🇵🇪',
    phoneCode: ['+51'],
    icaoPrefixes: ['SP'],
    registration: ['OB-'], // ⭐️ AGREGADO
    localCurrency: 'PEN',
    currencyName: 'Peruvian Sol',
    authorityOfficialName: 'Dirección General de Aeronáutica Civil',
    authorityAcronym: 'DGAC',
  ),
  CountryData(
    name: 'Philippines',
    flagEmoji: '🇵🇭',
    phoneCode: ['+63'],
    icaoPrefixes: ['RP'],
    registration: ['RP-'], // ⭐️ AGREGADO
    localCurrency: 'PHP',
    currencyName: 'Philippine Peso',
    authorityOfficialName: 'Civil Aviation Authority of the Philippines',
    authorityAcronym: 'CAAP',
  ),
  CountryData(
    name: 'Poland',
    flagEmoji: '🇵🇱',
    phoneCode: ['+48'],
    icaoPrefixes: ['EP'],
    registration: ['SP-', 'SN-'], // ⭐️ AGREGADO
    localCurrency: 'PLN',
    currencyName: 'Polish Złoty',
    authorityOfficialName: 'Civil Aviation Authority of Poland',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'Portugal',
    flagEmoji: '🇵🇹',
    phoneCode: ['+351'],
    icaoPrefixes: ['LP'],
    registration: ['CR-', 'CS-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Autoridade Nacional da Aviação Civil',
    authorityAcronym: 'ANAC',
  ),
  CountryData(
    name: 'Puerto Rico',
    flagEmoji: '🇵🇷',
    phoneCode: ['+1787', '+1939'],
    icaoPrefixes: ['TJ'],
    registration: ['N'], // ⭐️ AGREGADO (Registro estadounidense)
    localCurrency: 'USD',
    currencyName: 'US Dollar',
    authorityOfficialName: 'Federal Aviation Administration (de facto)',
    authorityAcronym: 'FAA',
  ),
  CountryData(
    name: 'Qatar',
    flagEmoji: '🇶🇦',
    phoneCode: ['+974'],
    icaoPrefixes: ['OT'],
    registration: ['A7-'], // ⭐️ AGREGADO
    localCurrency: 'QAR',
    currencyName: 'Qatari Riyal',
    authorityOfficialName: 'Civil Aviation Authority',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'Republic of the Congo',
    flagEmoji: '🇨🇬',
    phoneCode: ['+242'],
    icaoPrefixes: ['FC'],
    registration: ['TN-'], // ⭐️ AGREGADO
    localCurrency: 'XAF',
    currencyName: 'Central African CFA Franc',
    authorityOfficialName: 'Agence Nationale de l\'Aviation Civile',
    authorityAcronym: 'ANAC',
  ),
  CountryData(
    name: 'Romania',
    flagEmoji: '🇷🇴',
    phoneCode: ['+40'],
    icaoPrefixes: ['LR'],
    registration: ['YR-'], // ⭐️ AGREGADO
    localCurrency: 'RON',
    currencyName: 'Romanian Leu',
    authorityOfficialName: 'Autoritatea Aeronautică Civilă Română',
    authorityAcronym: 'AACR',
  ),
  CountryData(
    name: 'Russia (Russian Federation)',
    flagEmoji: '🇷🇺',
    phoneCode: ['+7'],
    icaoPrefixes: ['U'],
    registration: ['RA-', 'RF-'],
    localCurrency: 'RUB',
    currencyName: 'Russian Ruble',
    authorityOfficialName: 'Federal Air Transport Agency (Rosaviatsiya)',
    authorityAcronym: 'FATA',
  ),
  CountryData(
    name: 'Rwanda',
    flagEmoji: '🇷🇼',
    phoneCode: ['+250'],
    icaoPrefixes: ['HR'],
    registration: ['9XR-'], // ⭐️ AGREGADO
    localCurrency: 'RWF',
    currencyName: 'Rwandan Franc',
    authorityOfficialName: 'Rwanda Civil Aviation Authority',
    authorityAcronym: 'RCAA',
  ),
  CountryData(
    name: 'Saint Barthélemy',
    flagEmoji: '🇧🇱',
    phoneCode: ['+590'],
    icaoPrefixes: ['TFF'],
    registration: ['F-O'], // ⭐️ AGREGADO (Registro francés)
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Direction Générale de l\'Aviation Civile (DGAC)',
    authorityAcronym: 'DGAC',
  ),
  CountryData(
    name: 'Saint Helena',
    flagEmoji: '🇸🇭',
    phoneCode: ['+290'],
    icaoPrefixes: ['FH'],
    registration: ['VQ-H'], // ⭐️ AGREGADO
    localCurrency: 'SHP',
    currencyName: 'Saint Helena Pound',
    authorityOfficialName: 'St Helena Civil Aviation',
    authorityAcronym: 'SCA',
  ),
  CountryData(
    name: 'Saint Kitts and Nevis',
    flagEmoji: '🇰🇳',
    phoneCode: ['+1869'],
    icaoPrefixes: ['TK'],
    registration: ['V4-'], // ⭐️ AGREGADO
    localCurrency: 'XCD',
    currencyName: 'East Caribbean Dollar',
    authorityOfficialName: 'Eastern Caribbean Civil Aviation Authority',
    authorityAcronym: 'ECCAA',
  ),
  CountryData(
    name: 'Saint Lucia',
    flagEmoji: '🇱🇨',
    phoneCode: ['+1758'],
    icaoPrefixes: ['TL'],
    registration: ['J6-'], // ⭐️ AGREGADO
    localCurrency: 'XCD',
    currencyName: 'East Caribbean Dollar',
    authorityOfficialName: 'Eastern Caribbean Civil Aviation Authority',
    authorityAcronym: 'ECCAA',
  ),
  CountryData(
    name: 'Saint Martin (French part)',
    flagEmoji: '🇲🇫',
    phoneCode: ['+590'],
    icaoPrefixes: ['TFF'],
    registration: ['F-O'], // ⭐️ AGREGADO (Registro francés)
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Direction Générale de l\'Aviation Civile (DGAC)',
    authorityAcronym: 'DGAC',
  ),
  CountryData(
    name: 'Saint Pierre and Miquelon',
    flagEmoji: '🇵🇲',
    phoneCode: ['+508'],
    icaoPrefixes: ['LF'],
    registration: ['F-O'], // ⭐️ AGREGADO (Registro francés)
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Direction Générale de l\'Aviation Civile (DGAC)',
    authorityAcronym: 'DGAC',
  ),
  CountryData(
    name: 'Saint Vincent and the Grenadines',
    flagEmoji: '🇻🇨',
    phoneCode: ['+1784'],
    icaoPrefixes: ['TV'],
    registration: ['J8-'], // ⭐️ AGREGADO
    localCurrency: 'XCD',
    currencyName: 'East Caribbean Dollar',
    authorityOfficialName: 'Eastern Caribbean Civil Aviation Authority',
    authorityAcronym: 'ECCAA',
  ),
  CountryData(
    name: 'Samoa',
    flagEmoji: '🇼🇸',
    phoneCode: ['+685'],
    icaoPrefixes: ['NS'],
    registration: ['5W-'], // ⭐️ AGREGADO
    localCurrency: 'WST',
    currencyName: 'Samoan Tala',
    authorityOfficialName: 'Samoa Civil Aviation Division',
    authorityAcronym: 'CAD',
  ),
  CountryData(
    name: 'San Marino',
    flagEmoji: '🇸🇲',
    phoneCode: ['+378'],
    icaoPrefixes: ['LI'],
    registration: ['T7-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Autorità per l\'Aviazione Civile',
    authorityAcronym: 'AAC',
  ),
  CountryData(
    name: 'Sao Tome and Principe',
    flagEmoji: '🇸🇹',
    phoneCode: ['+239'],
    icaoPrefixes: ['FP'],
    registration: ['S9-'], // ⭐️ AGREGADO
    localCurrency: 'STN',
    currencyName: 'Sao Tome and Principe Dobra',
    authorityOfficialName: 'Autoridade Nacional de Aviação Civil',
    authorityAcronym: 'ANAC',
  ),
  CountryData(
    name: 'Saudi Arabia',
    flagEmoji: '🇸🇦',
    phoneCode: ['+966'],
    icaoPrefixes: ['OE'],
    registration: ['HZ-'], // ⭐️ AGREGADO
    localCurrency: 'SAR',
    currencyName: 'Saudi Riyal',
    authorityOfficialName: 'General Authority of Civil Aviation',
    authorityAcronym: 'GACA',
  ),
  CountryData(
    name: 'Senegal',
    flagEmoji: '🇸🇳',
    phoneCode: ['+221'],
    icaoPrefixes: ['GO'],
    registration: ['6V-'], // ⭐️ AGREGADO
    localCurrency: 'XOF',
    currencyName: 'West African CFA Franc',
    authorityOfficialName: 'Agence Nationale de l\'Aviation Civile',
    authorityAcronym: 'ANAC',
  ),
  CountryData(
    name: 'Serbia',
    flagEmoji: '🇷🇸',
    phoneCode: ['+381'],
    icaoPrefixes: ['LY'],
    registration: ['YU-'], // ⭐️ AGREGADO
    localCurrency: 'RSD',
    currencyName: 'Serbian Dinar',
    authorityOfficialName:
        'Civil Aviation Directorate of the Republic of Serbia',
    authorityAcronym: 'CAD',
  ),
  CountryData(
    name: 'Seychelles',
    flagEmoji: '🇸🇨',
    phoneCode: ['+248'],
    icaoPrefixes: ['FS'],
    registration: ['S7-'], // ⭐️ AGREGADO
    localCurrency: 'SCR',
    currencyName: 'Seychellois Rupee',
    authorityOfficialName: 'Seychelles Civil Aviation Authority',
    authorityAcronym: 'SCAA',
  ),
  CountryData(
    name: 'Sierra Leone',
    flagEmoji: '🇸🇱',
    phoneCode: ['+232'],
    icaoPrefixes: ['GF'],
    registration: ['9L-'], // ⭐️ AGREGADO
    localCurrency: 'SLL',
    currencyName: 'Sierra Leonean Leone',
    authorityOfficialName: 'Sierra Leone Civil Aviation Authority',
    authorityAcronym: 'SLCAA',
  ),
  CountryData(
    name: 'Singapore',
    flagEmoji: '🇸🇬',
    phoneCode: ['+65'],
    icaoPrefixes: ['WS'],
    registration: ['9V-'], // ⭐️ AGREGADO
    localCurrency: 'SGD',
    currencyName: 'Singapore Dollar',
    authorityOfficialName: 'Civil Aviation Authority of Singapore',
    authorityAcronym: 'CAAS',
  ),
  CountryData(
    name: 'Sint Maarten (Dutch part)',
    flagEmoji: '🇸🇽',
    phoneCode: ['+1721'],
    icaoPrefixes: ['TN'],
    registration: ['PJ-S'], // ⭐️ AGREGADO
    localCurrency: 'USD',
    currencyName: 'US Dollar',
    authorityOfficialName: 'Sint Maarten Civil Aviation Authority',
    authorityAcronym: 'SMCAA',
  ),
  CountryData(
    name: 'Slovakia',
    flagEmoji: '🇸🇰',
    phoneCode: ['+421'],
    icaoPrefixes: ['LZ'],
    registration: ['OM-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Civil Aviation Authority of the Slovak Republic',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'Slovenia',
    flagEmoji: '🇸🇮',
    phoneCode: ['+386'],
    icaoPrefixes: ['LJ'],
    registration: ['S5-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Civil Aviation Agency',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'Solomon Islands',
    flagEmoji: '🇸🇧',
    phoneCode: ['+677'],
    icaoPrefixes: ['AG'],
    registration: ['H4-'], // ⭐️ AGREGADO
    localCurrency: 'SBD',
    currencyName: 'Solomon Islands Dollar',
    authorityOfficialName: 'Civil Aviation Authority of Solomon Islands',
    authorityAcronym: 'CAASI',
  ),
  CountryData(
    name: 'Somalia',
    flagEmoji: '🇸🇴',
    phoneCode: ['+252'],
    icaoPrefixes: ['HC'],
    registration: ['6O-'], // ⭐️ AGREGADO
    localCurrency: 'SOS',
    currencyName: 'Somali Shilling',
    authorityOfficialName: 'Somali Civil Aviation Authority',
    authorityAcronym: 'SCAA',
  ),
  CountryData(
    name: 'South Africa',
    flagEmoji: '🇿🇦',
    phoneCode: ['+27'],
    icaoPrefixes: ['FA'],
    registration: ['ZS', 'ZT', 'ZU'], // ⭐️ AGREGADO
    localCurrency: 'ZAR',
    currencyName: 'South African Rand',
    authorityOfficialName: 'South African Civil Aviation Authority',
    authorityAcronym: 'SACAA',
  ),
  CountryData(
    name: 'South Korea',
    flagEmoji: '🇰🇷',
    phoneCode: ['+82'],
    icaoPrefixes: ['RK'],
    registration: ['HL-'], // ⭐️ AGREGADO
    localCurrency: 'KRW',
    currencyName: 'South Korean Won',
    authorityOfficialName: 'Korea Civil Aviation Authority',
    authorityAcronym: 'KCAA',
  ),
  CountryData(
    name: 'South Sudan',
    flagEmoji: '🇸🇸',
    phoneCode: ['+211'],
    icaoPrefixes: ['HSS'],
    registration: ['Z8-'], // ⭐️ AGREGADO
    localCurrency: 'SSP',
    currencyName: 'South Sudanese Pound',
    authorityOfficialName: 'South Sudan Civil Aviation Authority',
    authorityAcronym: 'SSCAA',
  ),
  CountryData(
    name: 'Spain',
    flagEmoji: '🇪🇸',
    phoneCode: ['+34'],
    icaoPrefixes: ['LE'],
    registration: ['EC-', 'EM-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Agencia Estatal de Seguridad Aérea',
    authorityAcronym: 'AESA',
  ),
  CountryData(
    name: 'Sri Lanka',
    flagEmoji: '🇱🇰',
    phoneCode: ['+94'],
    icaoPrefixes: ['VC'],
    registration: ['4R-'], // ⭐️ AGREGADO
    localCurrency: 'LKR',
    currencyName: 'Sri Lankan Rupee',
    authorityOfficialName: 'Civil Aviation Authority of Sri Lanka',
    authorityAcronym: 'CAASL',
  ),
  CountryData(
    name: 'Sudan',
    flagEmoji: '🇸🇩',
    phoneCode: ['+249'],
    icaoPrefixes: ['HS'],
    registration: ['ST-'], // ⭐️ AGREGADO
    localCurrency: 'SDG',
    currencyName: 'Sudanese Pound',
    authorityOfficialName: 'Sudan Civil Aviation Authority',
    authorityAcronym: 'SCAA',
  ),
  CountryData(
    name: 'Suriname',
    flagEmoji: '🇸🇷',
    phoneCode: ['+597'],
    icaoPrefixes: ['SM'],
    registration: ['PZ-'], // ⭐️ AGREGADO
    localCurrency: 'SRD',
    currencyName: 'Surinamese Dollar',
    authorityOfficialName: 'Directorate of Civil Aviation Suriname',
    authorityAcronym: 'CAS',
  ),
  CountryData(
    name: 'Sweden',
    flagEmoji: '🇸🇪',
    phoneCode: ['+46'],
    icaoPrefixes: ['ES'],
    registration: ['SE-'], // ⭐️ AGREGADO
    localCurrency: 'SEK',
    currencyName: 'Swedish Krona',
    authorityOfficialName: 'Swedish Transport Agency',
    authorityAcronym: 'Transportstyrelsen',
  ),
  CountryData(
    name: 'Switzerland',
    flagEmoji: '🇨🇭',
    phoneCode: ['+41'],
    icaoPrefixes: ['LS'],
    registration: ['HB-'], // ⭐️ AGREGADO
    localCurrency: 'CHF',
    currencyName: 'Swiss Franc',
    authorityOfficialName: 'Federal Office of Civil Aviation',
    authorityAcronym: 'FOCA',
  ),
  CountryData(
    name: 'Syria',
    flagEmoji: '🇸🇾',
    phoneCode: ['+963'],
    icaoPrefixes: ['OS'],
    registration: ['YK-'], // ⭐️ AGREGADO
    localCurrency: 'SYP',
    currencyName: 'Syrian Pound',
    authorityOfficialName: 'Syrian Civil Aviation Authority',
    authorityAcronym: 'SCAA',
  ),
  CountryData(
    name: 'Taiwan',
    flagEmoji: '🇹🇼',
    phoneCode: ['+886'],
    icaoPrefixes: ['RC'],
    registration: [
      'B-1',
      'B-2',
      'B-3',
      'B-4',
      'B-5',
      'B-6',
      'B-7',
      'B-8',
      'B-9',
      'B-0'
    ], // ⭐️ AGREGADO (Prefijo chino/Taiwán)
    localCurrency: 'TWD',
    currencyName: 'New Taiwan Dollar',
    authorityOfficialName: 'Civil Aeronautics Administration',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'Tajikistan',
    flagEmoji: '🇹🇯',
    phoneCode: ['+992'],
    icaoPrefixes: ['UT'],
    registration: ['EY-'], // ⭐️ AGREGADO
    localCurrency: 'TJS',
    currencyName: 'Tajikistani Somoni',
    authorityOfficialName: 'Civil Aviation Agency',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'Tanzania',
    flagEmoji: '🇹🇿',
    phoneCode: ['+255'],
    icaoPrefixes: ['HT'],
    registration: ['5H-'], // ⭐️ AGREGADO
    localCurrency: 'TZS',
    currencyName: 'Tanzanian Shilling',
    authorityOfficialName: 'Tanzania Civil Aviation Authority',
    authorityAcronym: 'TCAA',
  ),
  CountryData(
    name: 'Thailand',
    flagEmoji: '🇹🇭',
    phoneCode: ['+66'],
    icaoPrefixes: ['VT'],
    registration: ['HS-', 'U-'], // ⭐️ AGREGADO
    localCurrency: 'THB',
    currencyName: 'Thai Baht',
    authorityOfficialName: 'Civil Aviation Authority of Thailand',
    authorityAcronym: 'CAAT',
  ),
  CountryData(
    name: 'Timor-Leste',
    flagEmoji: '🇹🇱',
    phoneCode: ['+670'],
    icaoPrefixes: ['WP'],
    registration: ['4W-'], // ⭐️ AGREGADO
    localCurrency: 'USD',
    currencyName: 'US Dollar',
    authorityOfficialName: 'Autoridade de Aviação Civil',
    authorityAcronym: 'AAC',
  ),
  CountryData(
    name: 'Togo',
    flagEmoji: '🇹🇬',
    phoneCode: ['+228'],
    icaoPrefixes: ['DX'],
    registration: ['5V-'], // ⭐️ AGREGADO
    localCurrency: 'XOF',
    currencyName: 'West African CFA Franc',
    authorityOfficialName: 'Agence Nationale de l\'Aviation Civile',
    authorityAcronym: 'ANAC',
  ),
  CountryData(
    name: 'Tokelau',
    flagEmoji: '🇹🇰',
    phoneCode: ['+690'],
    icaoPrefixes: ['NZ'],
    registration: ['ZK-'], // ⭐️ AGREGADO (Registro neozelandés)
    localCurrency: 'NZD',
    currencyName: 'New Zealand Dollar',
    authorityOfficialName: 'Civil Aviation Authority of New Zealand (de facto)',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'Tonga',
    flagEmoji: '🇹🇴',
    phoneCode: ['+676'],
    icaoPrefixes: ['NF'],
    registration: ['A3-'], // ⭐️ AGREGADO
    localCurrency: 'TOP',
    currencyName: 'Tongan Paʻanga',
    authorityOfficialName: 'Civil Aviation Division',
    authorityAcronym: 'CAD',
  ),
  CountryData(
    name: 'Trinidad and Tobago',
    flagEmoji: '🇹🇹',
    phoneCode: ['+1868'],
    icaoPrefixes: ['TT'],
    registration: ['9Y-'], // ⭐️ AGREGADO
    localCurrency: 'TTD',
    currencyName: 'Trinidad and Tobago Dollar',
    authorityOfficialName: 'Civil Aviation Authority of Trinidad and Tobago',
    authorityAcronym: 'CAATT',
  ),
  CountryData(
    name: 'Tunisia',
    flagEmoji: '🇹🇳',
    phoneCode: ['+216'],
    icaoPrefixes: ['DT'],
    registration: ['TS-'], // ⭐️ AGREGADO
    localCurrency: 'TND',
    currencyName: 'Tunisian Dinar',
    authorityOfficialName: 'Office de l\'Aviation Civile et des Aéroports',
    authorityAcronym: 'OACA',
  ),
  CountryData(
    name: 'Turkey',
    flagEmoji: '🇹🇷',
    phoneCode: ['+90'],
    icaoPrefixes: ['LT'],
    registration: ['TC-'], // ⭐️ AGREGADO
    localCurrency: 'TRY',
    currencyName: 'Turkish Lira',
    authorityOfficialName: 'Directorate General of Civil Aviation',
    authorityAcronym: 'DGCA',
  ),
  CountryData(
    name: 'Turkmenistan',
    flagEmoji: '🇹🇲',
    phoneCode: ['+993'],
    icaoPrefixes: ['UT'],
    registration: ['EZ-'], // ⭐️ AGREGADO
    localCurrency: 'TMT',
    currencyName: 'Turkmenistani Manat',
    authorityOfficialName: 'Turkmenistan State Civil Aviation Service',
    authorityAcronym: 'TSCAS',
  ),
  CountryData(
    name: 'Turks and Caicos Islands',
    flagEmoji: '🇹🇨',
    phoneCode: ['+1649'],
    icaoPrefixes: ['MB'],
    registration: ['VQ-T'], // ⭐️ AGREGADO
    localCurrency: 'USD',
    currencyName: 'US Dollar',
    authorityOfficialName: 'Civil Aviation Authority',
    authorityAcronym: 'TCCAA',
  ),
  CountryData(
    name: 'Tuvalu',
    flagEmoji: '🇹🇻',
    phoneCode: ['+688'],
    icaoPrefixes: ['NV'],
    registration: ['T2-'], // ⭐️ AGREGADO
    localCurrency: 'AUD',
    currencyName: 'Australian Dollar',
    authorityOfficialName: 'Ministry of Communications and Transport',
    authorityAcronym: 'MCT',
  ),
  CountryData(
    name: 'Uganda',
    flagEmoji: '🇺🇬',
    phoneCode: ['+256'],
    icaoPrefixes: ['HU'],
    registration: ['5X-'], // ⭐️ AGREGADO
    localCurrency: 'UGX',
    currencyName: 'Ugandan Shilling',
    authorityOfficialName: 'Uganda Civil Aviation Authority',
    authorityAcronym: 'UCAA',
  ),
  CountryData(
    name: 'Ukraine',
    flagEmoji: '🇺🇦',
    phoneCode: ['+380'],
    icaoPrefixes: ['UK'],
    registration: ['UR-'], // ⭐️ AGREGADO
    localCurrency: 'UAH',
    currencyName: 'Ukrainian Hryvnia',
    authorityOfficialName: 'State Aviation Administration of Ukraine',
    authorityAcronym: 'SAAU',
  ),
  CountryData(
    name: 'United Arab Emirates',
    flagEmoji: '🇦🇪',
    phoneCode: ['+971'],
    icaoPrefixes: ['OM'],
    registration: ['A6-', 'DU-'], // ⭐️ AGREGADO
    localCurrency: 'AED',
    currencyName: 'United Arab Emirates Dirham',
    authorityOfficialName: 'General Civil Aviation Authority',
    authorityAcronym: 'GCAA',
  ),
  CountryData(
    name: 'United Kingdom',
    flagEmoji: '🇬🇧',
    phoneCode: ['+44'],
    icaoPrefixes: ['E', 'EG', 'EH'],
    registration: ['G-'], // ⭐️ AGREGADO
    localCurrency: 'GBP',
    currencyName: 'Pound Sterling',
    authorityOfficialName: 'Civil Aviation Authority',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'United States',
    flagEmoji: '🇺🇸',
    phoneCode: ['+1'],
    icaoPrefixes: ['K', 'P'],
    registration: ['N'], // ⭐️ AGREGADO
    localCurrency: 'USD',
    currencyName: 'US Dollar',
    authorityOfficialName: 'Federal Aviation Administration',
    authorityAcronym: 'FAA',
  ),
  CountryData(
    name: 'Uruguay',
    flagEmoji: '🇺🇾',
    phoneCode: ['+598'],
    icaoPrefixes: ['SU'],
    registration: ['CX-'], // ⭐️ AGREGADO
    localCurrency: 'UYU',
    currencyName: 'Uruguayan Peso',
    authorityOfficialName:
        'Dirección Nacional de Aviación Civil e Infraestructura Aeronáutica',
    authorityAcronym: 'DINACIA',
  ),
  CountryData(
    name: 'Uzbekistan',
    flagEmoji: '🇺🇿',
    phoneCode: ['+998'],
    icaoPrefixes: ['UT'],
    registration: ['UK'], // ⭐️ AGREGADO
    localCurrency: 'UZS',
    currencyName: 'Uzbekistani Som',
    authorityOfficialName:
        'State Inspection of the Republic of Uzbekistan for Flight Safety',
    authorityAcronym: 'SInFS',
  ),
  CountryData(
    name: 'Vanuatu',
    flagEmoji: '🇻🇺',
    phoneCode: ['+678'],
    icaoPrefixes: ['NV'],
    registration: ['YJ-'], // ⭐️ AGREGADO
    localCurrency: 'VUV',
    currencyName: 'Vanuatu Vatu',
    authorityOfficialName: 'Civil Aviation Authority of Vanuatu',
    authorityAcronym: 'CAAV',
  ),
  CountryData(
    name: 'Vatican City',
    flagEmoji: '🇻🇦',
    phoneCode: ['+379'],
    icaoPrefixes: ['LI'],
    registration: ['HV-'], // ⭐️ AGREGADO
    localCurrency: 'EUR',
    currencyName: 'Euro',
    authorityOfficialName: 'Italian Civil Aviation Authority (de facto)',
    authorityAcronym: 'ENAC',
  ),
  CountryData(
    name: 'Venezuela',
    flagEmoji: '🇻🇪',
    phoneCode: ['+58'],
    icaoPrefixes: ['SV'],
    registration: ['YV-'], // ⭐️ AGREGADO
    localCurrency: 'VED',
    currencyName: 'Venezuelan Bolívar Digital',
    authorityOfficialName: 'Instituto Nacional de Aeronáutica Civil',
    authorityAcronym: 'INAC',
  ),
  CountryData(
    name: 'Vietnam',
    flagEmoji: '🇻🇳',
    phoneCode: ['+84'],
    icaoPrefixes: ['VV'],
    registration: ['VN-'], // ⭐️ AGREGADO
    localCurrency: 'VND',
    currencyName: 'Vietnamese Đồng',
    authorityOfficialName: 'Civil Aviation Authority of Vietnam',
    authorityAcronym: 'CAAV',
  ),
  CountryData(
    name: 'Wallis and Futuna',
    flagEmoji: '🇼🇫',
    phoneCode: ['+681'],
    icaoPrefixes: ['NW'],
    registration: ['F-O'], // ⭐️ AGREGADO (Registro francés)
    localCurrency: 'XPF',
    currencyName: 'CFP Franc',
    authorityOfficialName: 'Direction Générale de l\'Aviation Civile (DGAC)',
    authorityAcronym: 'DGAC',
  ),
  CountryData(
    name: 'Yemen',
    flagEmoji: '🇾🇪',
    phoneCode: ['+967'],
    icaoPrefixes: ['OY'],
    registration: ['7O-'], // ⭐️ AGREGADO
    localCurrency: 'YER',
    currencyName: 'Yemeni Rial',
    authorityOfficialName: 'Civil Aviation and Meteorology Authority',
    authorityAcronym: 'CAMA',
  ),
  CountryData(
    name: 'Zambia',
    flagEmoji: '🇿🇲',
    phoneCode: ['+260'],
    icaoPrefixes: ['FL'],
    registration: ['9J-'], // ⭐️ AGREGADO
    localCurrency: 'ZMW',
    currencyName: 'Zambian Kwacha',
    authorityOfficialName: 'Civil Aviation Authority of Zambia',
    authorityAcronym: 'CAA',
  ),
  CountryData(
    name: 'Zimbabwe',
    flagEmoji: '🇿🇼',
    phoneCode: ['+263'],
    icaoPrefixes: ['FV'],
    registration: ['Z-'], // ⭐️ AGREGADO
    localCurrency: 'ZWL',
    currencyName: 'Zimbabwean Dollar',
    authorityOfficialName: 'Civil Aviation Authority of Zimbabwe',
    authorityAcronym: 'CAAZ',
  ),
];
