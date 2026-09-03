import 'package:flutter/material.dart';

import '../../models/transaction_model.dart';

/// Mot danh muc trong bo seed (chua co id, id do DB tu sinh).
class SeedCategory {
  final String name;
  final IconData icon;
  final Color color;
  final List<SeedChild> children;

  const SeedCategory({
    required this.name,
    required this.icon,
    required this.color,
    this.children = const <SeedChild>[],
  });
}

class SeedChild {
  final String name;
  final IconData icon;

  const SeedChild({required this.name, required this.icon});
}

/// Bo danh muc mac dinh kieu Money Lover. Seed 1 lan khi tao DB.
///
/// Danh muc con thua mau cua cha (chi khac icon) de nhin dong bo.
class CategorySeed {
  CategorySeed._();

  static const List<SeedCategory> expense = <SeedCategory>[
    SeedCategory(
      name: 'Ăn uống',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFEF5350),
      children: <SeedChild>[
        SeedChild(name: 'Đi chợ / Siêu thị', icon: Icons.shopping_cart_rounded),
        SeedChild(name: 'Nhà hàng', icon: Icons.dinner_dining_rounded),
        SeedChild(name: 'Cà phê', icon: Icons.local_cafe_rounded),
        SeedChild(name: 'Trà sữa / Đồ uống', icon: Icons.bubble_chart_rounded),
      ],
    ),
    SeedCategory(
      name: 'Di chuyển',
      icon: Icons.directions_car_rounded,
      color: Color(0xFF42A5F5),
      children: <SeedChild>[
        SeedChild(name: 'Xăng xe', icon: Icons.local_gas_station_rounded),
        SeedChild(name: 'Gửi xe', icon: Icons.local_parking_rounded),
        SeedChild(name: 'Taxi / Xe ôm', icon: Icons.local_taxi_rounded),
        SeedChild(name: 'Vé xe / Tàu', icon: Icons.confirmation_num_rounded),
      ],
    ),
    SeedCategory(
      name: 'Mua sắm',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFFAB47BC),
      children: <SeedChild>[
        SeedChild(name: 'Quần áo', icon: Icons.checkroom_rounded),
        SeedChild(name: 'Mỹ phẩm', icon: Icons.face_retouching_natural_rounded),
        SeedChild(name: 'Đồ điện tử', icon: Icons.devices_rounded),
        SeedChild(name: 'Đồ gia dụng', icon: Icons.blender_rounded),
      ],
    ),
    SeedCategory(
      name: 'Hóa đơn',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFFFA726),
      children: <SeedChild>[
        SeedChild(name: 'Điện', icon: Icons.bolt_rounded),
        SeedChild(name: 'Nước', icon: Icons.water_drop_rounded),
        SeedChild(name: 'Internet', icon: Icons.wifi_rounded),
        SeedChild(name: 'Điện thoại', icon: Icons.smartphone_rounded),
      ],
    ),
    SeedCategory(
      name: 'Nhà cửa',
      icon: Icons.home_rounded,
      color: Color(0xFF8D6E63),
      children: <SeedChild>[
        SeedChild(name: 'Tiền thuê nhà', icon: Icons.vpn_key_rounded),
        SeedChild(name: 'Sửa chữa', icon: Icons.handyman_rounded),
      ],
    ),
    SeedCategory(
      name: 'Sức khỏe',
      icon: Icons.favorite_rounded,
      color: Color(0xFF26A69A),
      children: <SeedChild>[
        SeedChild(name: 'Khám bệnh', icon: Icons.local_hospital_rounded),
        SeedChild(name: 'Thuốc', icon: Icons.medication_rounded),
        SeedChild(name: 'Thể thao / Gym', icon: Icons.fitness_center_rounded),
      ],
    ),
    SeedCategory(
      name: 'Giải trí',
      icon: Icons.sports_esports_rounded,
      color: Color(0xFFEC407A),
      children: <SeedChild>[
        SeedChild(name: 'Xem phim', icon: Icons.movie_rounded),
        SeedChild(name: 'Du lịch', icon: Icons.beach_access_rounded),
        SeedChild(name: 'Đăng ký / Subscription', icon: Icons.subscriptions_rounded),
      ],
    ),
    SeedCategory(
      name: 'Học tập',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF5C6BC0),
      children: <SeedChild>[
        SeedChild(name: 'Học phí', icon: Icons.school_rounded),
        SeedChild(name: 'Sách vở', icon: Icons.auto_stories_rounded),
      ],
    ),
    SeedCategory(
      name: 'Gia đình',
      icon: Icons.family_restroom_rounded,
      color: Color(0xFF7E57C2),
      children: <SeedChild>[
        SeedChild(name: 'Con cái', icon: Icons.child_care_rounded),
        SeedChild(name: 'Hiếu hỉ', icon: Icons.card_giftcard_rounded),
        SeedChild(name: 'Biếu tặng', icon: Icons.volunteer_activism_rounded),
      ],
    ),
    SeedCategory(
      name: 'Khác',
      icon: Icons.more_horiz_rounded,
      color: Color(0xFF78909C),
      children: <SeedChild>[],
    ),
  ];

  static const List<SeedCategory> income = <SeedCategory>[
    SeedCategory(
      name: 'Lương',
      icon: Icons.payments_rounded,
      color: Color(0xFF66BB6A),
      children: <SeedChild>[
        SeedChild(name: 'Lương chính', icon: Icons.account_balance_wallet_rounded),
        SeedChild(name: 'Làm thêm', icon: Icons.more_time_rounded),
      ],
    ),
    SeedCategory(
      name: 'Thưởng',
      icon: Icons.card_giftcard_rounded,
      color: Color(0xFFFFCA28),
      children: <SeedChild>[
        SeedChild(name: 'Thưởng lễ Tết', icon: Icons.celebration_rounded),
        SeedChild(name: 'Thưởng hiệu suất', icon: Icons.emoji_events_rounded),
      ],
    ),
    SeedCategory(
      name: 'Đầu tư',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF29B6F6),
      children: <SeedChild>[
        SeedChild(name: 'Lãi tiết kiệm', icon: Icons.savings_rounded),
        SeedChild(name: 'Cổ tức', icon: Icons.stacked_line_chart_rounded),
      ],
    ),
    SeedCategory(
      name: 'Thu khác',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF9CCC65),
      children: <SeedChild>[
        SeedChild(name: 'Được tặng', icon: Icons.redeem_rounded),
        SeedChild(name: 'Bán đồ', icon: Icons.sell_rounded),
      ],
    ),
  ];

  static List<SeedCategory> of(TransactionType type) =>
      type.isExpense ? expense : income;
}
