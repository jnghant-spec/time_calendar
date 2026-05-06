enum MembershipTier { free, basic, premium }

class TierBenefits {
  final String label;
  final double priceMonthly;
  final double priceYearly;
  final int reminderQuota;
  final int ethnicFestivalQuota;
  final int religiousFestivalQuota;
  final bool lunarBirthday;
  final bool customPhotoUpload;
  final int photosPerEvent;
  final bool batchImportContacts;
  final bool festivalShareCard;

  const TierBenefits({
    required this.label,
    required this.priceMonthly,
    required this.priceYearly,
    required this.reminderQuota,
    required this.ethnicFestivalQuota,
    required this.religiousFestivalQuota,
    required this.lunarBirthday,
    required this.customPhotoUpload,
    required this.photosPerEvent,
    required this.batchImportContacts,
    required this.festivalShareCard,
  });
}

class MembershipConfig {
  static const Map<MembershipTier, TierBenefits> benefits = {
    MembershipTier.free: TierBenefits(
      label: '免费版',
      priceMonthly: 0,
      priceYearly: 0,
      reminderQuota: 8,
      ethnicFestivalQuota: 3,
      religiousFestivalQuota: 3,
      lunarBirthday: false,
      customPhotoUpload: false,
      photosPerEvent: 0,
      batchImportContacts: false,
      festivalShareCard: false,
    ),
    MembershipTier.basic: TierBenefits(
      label: '基础版',
      priceMonthly: 4.99,
      priceYearly: 39.9,
      reminderQuota: 20,
      ethnicFestivalQuota: 8,
      religiousFestivalQuota: 8,
      lunarBirthday: true,
      customPhotoUpload: true,
      photosPerEvent: 3,
      batchImportContacts: false,
      festivalShareCard: false,
    ),
    MembershipTier.premium: TierBenefits(
      label: '高级版',
      priceMonthly: 9.99,
      priceYearly: 79.9,
      reminderQuota: 200,
      ethnicFestivalQuota: 20,
      religiousFestivalQuota: -1,
      lunarBirthday: true,
      customPhotoUpload: true,
      photosPerEvent: 10,
      batchImportContacts: true,
      festivalShareCard: true,
    ),
  };
}
