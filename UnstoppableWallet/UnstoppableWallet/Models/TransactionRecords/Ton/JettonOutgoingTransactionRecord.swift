import Foundation
import MarketKit
import TonKit

class JettonOutgoingTransactionRecord: TonTransactionRecord {
    let transfers: [Transfer]
    let totalValue: TransactionValue
    let sentToSelf: Bool

    init(source: TransactionSource, event: AccountEvent, feeToken: Token, token: Token, sentToSelf: Bool) {
        var totalAmount: Decimal = 0

        transfers = event.actions.compactMap { transfer in
            guard let transfer = transfer as? JettonTransfer,
                let recipient = transfer.recipient else {
                return nil
            }
            let amount = JettonAdapter.amount(kitAmount: transfer.amount, decimals: token.decimals)
            var value: Decimal = 0
            if !amount.isZero {
                value = Decimal(sign: .minus, exponent: amount.exponent, significand: amount.significand)
                totalAmount += value
            }

            return TonTransactionRecord.Transfer(
                address: recipient.address.toString(bounceable: TonAdapter.bounceableDefault),
                value: .coinValue(token: token, value: value)
            )
        }

        totalValue = .coinValue(token: token, value: totalAmount)
        self.sentToSelf = sentToSelf

        super.init(source: source, event: event, feeToken: feeToken)
    }

    override var mainValue: TransactionValue? {
        totalValue
    }
}
