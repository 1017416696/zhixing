//
//  EditLocation.swift
//  zhixing
//
//  Created by 曹骁凡 on 2024/9/13.
//

import SwiftUI
import MapKit
import Contacts

struct LocationInputView: View {
    @Binding var locationName: String
    @Binding var location: CLLocationCoordinate2D?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("搜索或输入地址", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .onChange(of: searchText) { _, newValue in
                        searchLocation(newValue)
                    }
                
                List(searchResults, id: \.self) { item in
                    Button(action: {
                        selectLocation(item)
                    }) {
                        VStack(alignment: .leading) {
                            Text(item.name ?? "")
                                .font(.headline)
                            Text(item.placemark.formattedAddress ?? "")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationBarTitle("输入位置", displayMode: .inline)
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("完成") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func searchLocation(_ query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            guard let response = response else { return }
            self.searchResults = response.mapItems
        }
    }
    
    private func selectLocation(_ item: MKMapItem) {
        locationName = item.name ?? ""
        location = item.placemark.coordinate
        presentationMode.wrappedValue.dismiss()
    }
}

extension MKPlacemark {
    var formattedAddress: String? {
        let addressComponents = [
            thoroughfare,
            subThoroughfare,
            locality,
            subLocality,
            administrativeArea,
            postalCode,
            country
        ].compactMap { $0 }
        
        return addressComponents.joined(separator: ", ")
    }
}
