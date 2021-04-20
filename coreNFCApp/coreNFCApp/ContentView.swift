//
//  ContentView.swift
//  coreNFCApp
//
//  Created by 岡優志 on 2020/08/31.
//

import SwiftUI
import CoreNFC

struct ContentView: View {
    @State var data = ""
    @State var showWrite = false
    let holder = "読み込んだ情報を表示"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30){
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 20)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.black, lineWidth: 2)
                        )
                    TextField("読み込んだ情報を表示", text: self.$data)
                        .foregroundColor(self.data.isEmpty ? .gray : .black)
                        .padding()
                }.frame(height: UIScreen.main.bounds.height * 0.3)
                
                //Read Button
                nfcButton(data: self.$data)
                    .frame(height: UIScreen.main.bounds.height * 0.05)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                
                //Write Button
                NavigationLink(destination: WriteView(isActive: $showWrite), isActive: $showWrite) {
                    Button(action: {
                        self.showWrite.toggle()
                    }) {
                        Text("Write")
                            .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.05)
                    }
                    .foregroundColor(.white)
                    .background(Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                
                
                Spacer()
            }.frame(width: UIScreen.main.bounds.width * 0.9, alignment: .center)
            .navigationBarTitle("NFC Read/Write", displayMode: .large)
            .padding(.top, 20)
        }
    }
}




//WriteView

struct PickerPayload : Identifiable{
    var id = UUID()
    var type : RecordType
    var pickerMessage : String
}


struct WriteView : View {
    @State var record = ""
    @State private var selection = 0
    
    @Binding var isActive : Bool
    var sessionWrite = NFCSessionWrite()
    var recordType = [PickerPayload(type: .text, pickerMessage: "Text"), PickerPayload(type: .url, pickerMessage: "URL")]
    
    var body : some View {
        GeometryReader { reader in
            Form {
                Section {
                    TextField("書込内容を記入して下さい", text: self.$record)
                }
                
                Section {
                    Picker(selection: self.$selection, label: Text("記録したいものを選択して下さい。")) {
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


//Write Button
enum RecordType {
    case text, url
}

class NFCSessionWrite : NSObject, NFCNDEFReaderSessionDelegate {
    var session : NFCNDEFReaderSession?
    var message = ""
    var recordType : RecordType = .text
    
    func beginScanning(message : String, recordType : RecordType) {
        guard NFCNDEFReaderSession.readingAvailable else {
            print("スキャンできません。")
            return
        }
        self.message = message
        self.recordType = recordType
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "メッセージを書き込むには、iPhoneをTagに近づけて下さい。"
        session?.begin()
    }
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        // 追加のアクションを追加したくない場合を除き、ここでは何もしません
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // 独自のエラーを実装できます
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // 停止する為に必要です
        
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if tags.count > 1 {
            let retryInterval = DispatchTimeInterval.milliseconds(2000)
            session.alertMessage = "複数のタグが検出されました。 すべてのタグを削除して、もう一度お試しください。"
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                session.restartPolling()
            })
            return
        }
        // 見つかったタグに接続し、それにNDEFメッセージを書き込みます
        let tag = tags.first!
        print("Tagの取得に成功")
        session.connect(to: tag, completionHandler: { (error: Error?) in
            if nil != error {
                session.alertMessage = "Tagに接続できません"
                session.invalidate()
                print("接続エラー")
                return
            }
            
            tag.queryNDEFStatus(completionHandler: { (ndefStatus: NFCNDEFStatus, capacity: Int, error: Error?) in
                guard error == nil else {
                    session.alertMessage = "このTagは照会できません"
                    session.invalidate()
                    print("照会できません")
                    return
                }
                
                switch ndefStatus {
                case .notSupported:
                    print("対応していません")
                    session.alertMessage = "このTagは対応していません"
                    session.invalidate()
                case .readOnly:
                    print("読み取り専用")
                    session.alertMessage = "このTagは読み取り専用です"
                    session.invalidate()
                case .readWrite:
                       print("書き込み可能")

                       let payLoad : NFCNDEFPayload?
                       switch self.recordType {
                       case .text:
                           guard !self.message.isEmpty else {
                               session.alertMessage = "データが空です"
                               session.invalidate(errorMessage: "テキストデータが空です")
                               return
                           }
                           
                        
                        //読み込んだメッセージを返す
                           payLoad = NFCNDEFPayload(format: .nfcWellKnown, type: "T".data(using: .utf8)! , identifier: "Text".data(using: .utf8)!,payload: "\u{02}\(self.message)".data(using: .utf8)!)
                           
                       case .url:
                           // 読み取ったdataを検証する
                           guard let url = URL(string: self.message) else {
                               session.alertMessage = "認識できませんでした"
                               session.invalidate(errorMessage: "読み取ったデータはURLではありません")
                               return
                           }
                           payLoad = NFCNDEFPayload.wellKnownTypeURIPayload(url: url)
                       }

                       let NFCMessage = NFCNDEFMessage(records: [payLoad!])
                       tag.writeNDEF(NFCMessage, completionHandler: { (error: Error?) in
                           if nil != error {
                               session.alertMessage = "書き込みに失敗しました！: \(error!)"
                               print("fails: \(error!.localizedDescription)")
                           } else {
                               session.alertMessage = "書き込みに成功しました！"
                               print("successs")
                           }
                           session.invalidate()
                       })
                @unknown default:
                    print("エラー")
                    session.alertMessage = "不明なTagです"
                    session.invalidate()
                }
            })
        })
    }
    
    
    
}






//Read Button

struct nfcButton : UIViewRepresentable {
    @Binding var data : String
    func makeUIView(context: UIViewRepresentableContext<nfcButton>) -> UIButton {
        let button = UIButton()
        button.setTitle("Read", for: .normal)
        button.backgroundColor = UIColor.gray
        button.addTarget(context.coordinator, action: #selector(context.coordinator.beginScan(_:)), for: .touchUpInside)
        return button
    }
    func updateUIView(_ uiView: UIButton, context: UIViewRepresentableContext<nfcButton>) {
        
    }
    func makeCoordinator() -> nfcButton.Coordinator {
        return Coordinator(data: $data)
    }
    
    class Coordinator : NSObject, NFCNDEFReaderSessionDelegate {
        var session : NFCReaderSession?
        @Binding var data : String
        
        init(data: Binding<String>) {
            _data = data
        }
        
        @objc func beginScan(_ sender: Any) {
            guard NFCNDEFReaderSession.readingAvailable else {
                print("このタグは読み込む事ができません")
                return
            }
            
            session = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: true)
            session?.alertMessage = "スキャンします。 iPhoneを近づけて下さい"
            session?.begin()
        }
        
        
        func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
            if let readerError = error as? NFCReaderError{
                
                if (readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead)
                    && (readerError.code != .readerSessionInvalidationErrorUserCanceled) {
                    print("読み込みできませんでした")
                }
            }
            
            self.session = nil
            
        }
        
        func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
            guard
                let nfcMess = messages.first,
                let record = nfcMess.records.first,
                record.typeNameFormat == .absoluteURI || record.typeNameFormat == .nfcWellKnown,
                let payload = String(data: record.payload, encoding: .utf8)
            else {
                return
            }
            
            print(payload)
            self.data = payload
        }
    }
}





struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
