class PaymentDetail {
  final int? id;
  final int transactionId;
  final String paymentType;
  final double amount;
  final String? referenceNo;
  final String? cardLastFour;
  final DateTime createdAt;

  PaymentDetail({
    this.id,
    required this.transactionId,
    required this.paymentType,
    required this.amount,
    this.referenceNo,
    this.cardLastFour,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transactionId': transactionId,
      'paymentType': paymentType,
      'amount': amount,
      'referenceNo': referenceNo,
      'cardLastFour': cardLastFour,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PaymentDetail.fromMap(Map<String, dynamic> map) {
    return PaymentDetail(
      id: map['id'] as int?,
      transactionId: map['transactionId'] as int,
      paymentType: map['paymentType'] as String,
      amount: (map['amount'] as num).toDouble(),
      referenceNo: map['referenceNo'] as String?,
      cardLastFour: map['cardLastFour'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

// Enum for payment types
enum PaymentType {
  cash,
  transfer,
  qris,
  creditCard,
  debitCard,
  tempo,
}

extension PaymentTypeExt on PaymentType {
  String get displayName {
    switch (this) {
      case PaymentType.cash:
        return 'Tunai';
      case PaymentType.transfer:
        return 'Transfer';
      case PaymentType.qris:
        return 'QRIS';
      case PaymentType.creditCard:
        return 'Kartu Kredit';
      case PaymentType.debitCard:
        return 'Kartu Debit';
      case PaymentType.tempo:
        return 'Tempo';
    }
  }

  String get code {
    switch (this) {
      case PaymentType.cash:
        return 'CASH';
      case PaymentType.transfer:
        return 'TRANSFER';
      case PaymentType.qris:
        return 'QRIS';
      case PaymentType.creditCard:
        return 'CREDIT_CARD';
      case PaymentType.debitCard:
        return 'DEBIT_CARD';
      case PaymentType.tempo:
        return 'TEMPO';
    }
  }

  static PaymentType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'CASH':
        return PaymentType.cash;
      case 'TRANSFER':
        return PaymentType.transfer;
      case 'QRIS':
        return PaymentType.qris;
      case 'CREDIT_CARD':
        return PaymentType.creditCard;
      case 'DEBIT_CARD':
        return PaymentType.debitCard;
      case 'TEMPO':
        return PaymentType.tempo;
      default:
        return PaymentType.cash;
    }
  }
}
