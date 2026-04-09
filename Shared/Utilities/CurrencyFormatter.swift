import Foundation

struct CurrencyFormatter {
    static let shared = CurrencyFormatter()
    private init() {}

    func format(_ amount: Int, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: Double(amount) / 100.0)) ?? "\(amount)"
    }
    
    func formatSigned(_ amount: Int, currencyCode: String) -> String {
        let absAmount = abs(amount)
        let formatted = format(absAmount, currencyCode: currencyCode)
        return amount < 0 ? "-\(formatted)" : "+\(formatted)"
    }

    static let supportedCurrencies = [
        ("USD", "US Dollar"), ("EUR", "Euro"), ("GBP", "British Pound"),
        ("JPY", "Japanese Yen"), ("CAD", "Canadian Dollar"), ("AUD", "Australian Dollar"),
        ("CHF", "Swiss Franc"), ("CNY", "Chinese Yuan"), ("INR", "Indian Rupee"),
        ("BRL", "Brazilian Real"), ("MXN", "Mexican Peso"), ("KRW", "South Korean Won"),
        ("SGD", "Singapore Dollar"), ("NZD", "New Zealand Dollar"), ("NOK", "Norwegian Krone"),
        ("SEK", "Swedish Krona"), ("DKK", "Danish Krone"), ("PLN", "Polish Złoty"),
        ("CZK", "Czech Koruna"), ("HUF", "Hungarian Forint"), ("RUB", "Russian Ruble"),
        ("TRY", "Turkish Lira"), ("ZAR", "South African Rand"), ("AED", "UAE Dirham"),
        ("SAR", "Saudi Riyal"), ("THB", "Thai Baht"), ("MYR", "Malaysian Ringgit"),
        ("IDR", "Indonesian Rupiah"), ("PHP", "Philippine Peso"), ("VND", "Vietnamese Dong")
    ]
}