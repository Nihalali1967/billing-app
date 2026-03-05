class CreditTransaction {
  final int id;
  final String type;
  final double amount;
  final double balanceAfter;
  final String? notes;
  final String? userName;
  final int? billId;
  final String? billNumber;
  final DateTime? createdAt;

  CreditTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.notes,
    this.userName,
    this.billId,
    this.billNumber,
    this.createdAt,
  });

  factory CreditTransaction.fromJson(Map<String, dynamic> json) {
    return CreditTransaction(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      balanceAfter: double.tryParse(json['balance_after']?.toString() ?? '0') ?? 0,
      notes: json['notes'],
      userName: json['user']?['name'],
      billId: json['bill']?['id'],
      billNumber: json['bill']?['bill_number'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}
