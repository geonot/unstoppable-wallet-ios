import BigInt
import Foundation
import MarketKit
import TonKit
import TonSwift

class JettonIncomingTransactionRecord: TonTransactionRecord {
    let transfer: TonTransactionRecord.Transfer?

    init(source: TransactionSource, event: AccountEvent, feeToken: Token, token: Token) {
        transfer = event
            .actions
            .compactMap { $0 as? JettonTransfer }
            .first
            .flatMap { transfer in
                guard let recipient = transfer.recipient else { return nil }
                return TonTransactionRecord.Transfer(
                    address: recipient.address.toString(bounceable: TonAdapter.bounceableDefault),
                    value: .coinValue(token: token, value: JettonAdapter.amount(kitAmount: transfer.amount, decimals: token.decimals))
                )
            }

        super.init(source: source, event: event, feeToken: feeToken)
    }

    override var mainValue: TransactionValue? {
        transfer?.value
    }
}
