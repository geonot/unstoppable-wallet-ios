import BigInt
import Foundation
import MarketKit
import TonKit

class TonTransactionConverter {
    private let coinManager: CoinManager
    private let tonKit: TonKit.Kit
    private let source: TransactionSource
    private let baseToken: Token

    init(source: TransactionSource, baseToken: Token, coinManager: CoinManager, tonKit: TonKit.Kit) {
        self.coinManager = coinManager
        self.tonKit = tonKit
        self.source = source
        self.baseToken = baseToken
    }

    private func convertAmount(amount: BigUInt, decimals: Int, sign: FloatingPointSign) -> Decimal {
        guard let significand = Decimal(string: amount.description), significand != 0 else {
            return 0
        }

        return Decimal(sign: sign, exponent: -decimals, significand: significand)
    }

    private func baseCoinValue(value: BigUInt, sign: FloatingPointSign) -> TransactionValue {
        let amount = convertAmount(amount: value, decimals: baseToken.decimals, sign: sign)
        return .coinValue(token: baseToken, value: amount)
    }
}

extension TonTransactionConverter {
    func transactionRecord(fromTransaction fullTransaction: FullTransaction) -> TonTransactionRecord {
        let event = fullTransaction.event

        switch fullTransaction.decoration {
        case is TonKit.IncomingDecoration:
            return TonIncomingTransactionRecord(
                source: source,
                event: event,
                feeToken: baseToken,
                token: baseToken
            )

        case let decoration as TonKit.OutgoingDecoration:
            return TonOutgoingTransactionRecord(
                source: source,
                event: event,
                feeToken: baseToken,
                token: baseToken,
                sentToSelf: decoration.sentToSelf
            )

        case is TonKit.IncomingJettonDecoration:
            return JettonIncomingTransactionRecord(
                source: source,
                event: event,
                feeToken: baseToken,
                token: baseToken//jettonToken
            )

        case let decoration as TonKit.OutgoingJettonDecoration:
            return JettonOutgoingTransactionRecord(
                source: source,
                event: event,
                feeToken: baseToken,
                token: baseToken,//jettonToken,
                sentToSelf: decoration.sentToSelf
            )

        default: ()
        }

        return TonTransactionRecord(
            source: source,
            event: event,
            feeToken: baseToken
        )
    }
}
