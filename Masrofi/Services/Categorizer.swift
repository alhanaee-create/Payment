import Foundation

/// يخمّن التصنيف من اسم المتجر. تقدر تغيّره بعدين من التطبيق.
enum Categorizer {
    private static let rules: [(ExpenseCategory, [String])] = [
        (.coffee, ["starbucks", "coffee", "cafe", "café", "barns", "dunkin", "tim hortons", "costa", "caribou", "dose", "half million", "قهوة", "كافيه", "كوفي", "ستاربكس", "بارنز"]),
        (.fuel, ["aldrees", "sasco", "petromin", "naft", "adnoc", "enoc", "eppco", "shell", "fuel", "petrol", "station", "الدريس", "ساسكو", "بترومين", "نفط", "محطة", "ادنوك"]),
        (.groceries, ["panda", "danube", "othaim", "tamimi", "lulu", "carrefour", "nesto", "spinneys", "union coop", "market", "supermarket", "hypermarket", "بنده", "الدانوب", "العثيم", "التميمي", "لولو", "كارفور", "سوبرماركت", "تموينات", "بقالة"]),
        (.food, ["mcdonald", "kfc", "albaik", "herfy", "kudu", "burger", "pizza", "shawarma", "restaurant", "grill", "kitchen", "subway", "hardee", "popeyes", "talabat", "hungerstation", "jahez", "deliveroo", "careem food", "البيك", "هرفي", "كودو", "مطعم", "شاورما", "برجر", "جاهز", "هنقرستيشن", "طلبات"]),
        (.transport, ["uber", "careem", "bolt", "taxi", "metro", "parking", "salik", "darb", "اوبر", "كريم", "تاكسي", "مواقف", "سالك"]),
        (.health, ["pharmacy", "nahdi", "dawaa", "aster", "boots", "hospital", "clinic", "صيدلية", "النهدي", "الدواء", "مستشفى", "عيادة"]),
        (.entertainment, ["cinema", "vox", "muvi", "amc", "netflix", "spotify", "playstation", "steam", "سينما", "موفي"]),
        (.bills, ["stc", "mobily", "zain", "etisalat", "du ", "ooredoo", "electric", "sec ", "water", "كهرباء", "مياه", "اتصالات", "موبايلي", "زين"]),
        (.shopping, ["ikea", "jarir", "extra", "noon", "amazon", "zara", "h&m", "centrepoint", "apple", "mall", "store", "shop", "جرير", "اكسترا", "نون", "امازون", "مول", "متجر"]),
    ]

    static func guess(_ merchant: String) -> ExpenseCategory {
        let m = " " + merchant.lowercased() + " "
        for (category, words) in rules where words.contains(where: { m.contains($0) }) {
            return category
        }
        return .other
    }
}
