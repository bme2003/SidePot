//
//  ContactPicker.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//

import SwiftUI
import ContactsUI

struct SelectedContact {
    let name: String
    let identifier: String
}

struct ContactPicker: UIViewControllerRepresentable {
    var onPick: (SelectedContact) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(value: true)
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (SelectedContact) -> Void

        init(onPick: @escaping (SelectedContact) -> Void) {
            self.onPick = onPick
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let formatter = CNContactFormatter()
            formatter.style = .fullName
            let name = formatter.string(from: contact) ?? "Contact"
            onPick(SelectedContact(name: name, identifier: contact.identifier))
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {}
    }
}
