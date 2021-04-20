//
//  nfcWriteView.swift
//  coreNFCApp
//
//  Created by 岡優志 on 2020/09/02.
//

import SwiftUI
import CoreNFC

struct PickerPayload : Identifiable{
    var id = UUID()
    var type : RecordType
    var pickerMessage : String
}

struct nfcWriteView: View {
            @State var record = ""
            @State private var selection = 0
            @Binding var isActive : Bool
            var sessionWrite = NFCSessionWrite()
            var recordType = [PickerPayload(type: .text, pickerMessage: "Text"), PickerPayload(type: .url, pickerMessage: "URL")]
            
            var body : some View {
                GeometryReader { reader in
                    NavigationView{
                        Section {
                            TextField("Message here...", text: self.$record)
                        }
                        
                        Section {
                            Picker(selection: self.$selection, label: Text("Pick A Record Type")) {
                                ForEach(0..<self.recordType.count) {
                                    Text(self.recordType[$0].pickerMessage)
                                }
                            }
                        }
                        
                        Section {
                            Button(action: {
                                self.sessionWrite.beginScanning(message: self.record, recordType: self.recordType[self.selection].type)
                            }) {
                                Text("Write")
                                
                            }
                        }
                    }
                    .navigationBarTitle("NFC Write")
                    .navigationBarItems(leading:
                        Button(action: {
                            self.isActive.toggle()
                        }) {
                        }
                    )
                    
                }
            }
        }
 






struct nfcWriteView_Previews: PreviewProvider {
    static var previews: some View {
        nfcWriteView()
    }
}
