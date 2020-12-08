// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum WalletEntryPoint { 
    case createInstantWallet
    case importWallet
    case watchWallet(address: AlphaWallet.Address?)
}
