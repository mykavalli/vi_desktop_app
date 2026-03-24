class CurrencyFormat {
  static String formatNumberOnly(double value) {
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  static String formatVN(double value) {
    String formattedNum = formatNumberOnly(value);
    
    return '$formattedNum (VNĐ)';
  }

  static String _numberToWords(int number) {
    if (number == 0) return 'không đồng';
    
    const units = ['', 'nghìn', 'triệu', 'tỉ', 'nghìn tỉ', 'triệu tỉ'];
    
    num currentNumber = number.abs();
    int unitIndex = 0;
    String result = '';
    
    while (currentNumber > 0) {
      int chunk = (currentNumber % 1000).toInt();
      if (chunk > 0) {
        String chunkText = _chunkToWords(chunk, currentNumber < number.abs());
        result = '$chunkText ${units[unitIndex]} $result'.trim();
      }
      currentNumber = currentNumber ~/ 1000;
      unitIndex++;
    }
    
    return result.replaceAll(RegExp(r'\s+'), ' ').trim() + (number < 0 ? ' âm đồng' : ' đồng');
  }

  static String _chunkToWords(int number, bool readHundreds) {
    const ones = ['không', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín'];
    
    int hundreds = number ~/ 100;
    int remainder = number % 100;
    int tens = remainder ~/ 10;
    int unitsValue = remainder % 10;
    
    String result = '';
    
    if (readHundreds || hundreds > 0) {
      result += '${ones[hundreds]} trăm';
    }
    
    if (tens > 1) {
      result += ' ${ones[tens]} mươi';
      if (unitsValue == 1) {
        result += ' mốt';
      } else if (unitsValue == 4) {
        result += ' tư';
      } else if (unitsValue == 5) {
        result += ' lăm';
      } else if (unitsValue > 0) {
        result += ' ${ones[unitsValue]}';
      }
    } else if (tens == 1) {
      result += ' mười';
      if (unitsValue == 5) {
        result += ' lăm';
      } else if (unitsValue > 0) {
        result += ' ${ones[unitsValue]}';
      }
    } else if (tens == 0 && unitsValue > 0) {
      if (hundreds > 0 || readHundreds) {
        result += ' lẻ';
      }
      result += ' ${ones[unitsValue]}';
    }
    
    return result.trim();
  }
}
