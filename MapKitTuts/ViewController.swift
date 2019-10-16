//
//  ViewController.swift
//  MapKitTuts
//
//  Created by Isaac Iniongun on 15/10/2019.
//  Copyright © 2019 Isaac Iniongun. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController {

    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var mapview: MKMapView!
    @IBOutlet weak var goButton: UIButton!
    
    let locationManager = CLLocationManager()
    let regionInMeters: Double = 10000
    var previousLocation: CLLocation?
    
    let geoCoder = CLGeocoder()
    var directionsArray: [MKDirections] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        goButton.layer.cornerRadius = goButton.frame.size.height/2
        checkLocationServices()
    }
    
    @IBAction func goButtonTapped(_ sender: UIButton) {
        getDirections()
    }
    
    func setUpLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func centerViewOnUserLocation() {
        if let location = locationManager.location?.coordinate {
            let region = MKCoordinateRegion.init(center: location, latitudinalMeters: regionInMeters, longitudinalMeters: regionInMeters)
            mapview.setRegion(region, animated: true)
        }
    }
    
    func checkLocationServices() {
        if CLLocationManager.locationServicesEnabled() {
            setUpLocationManager()
            checklocationAuthorization()
        } else {
            //Inform the user that their location services are turned off and that they should turn them back on.
        }
    }
    
    func checklocationAuthorization() {
        switch CLLocationManager.authorizationStatus() {
        case .authorizedWhenInUse:
            startTrackingUserLocation()
            break
        case .denied:
            // Show alert instructing them how to turn on permissions
            break
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted:
            // Show an alert letting them know what's up
            //Restriction could be due to parental guidance
            break
        case .authorizedAlways:
            break
        @unknown default:
            break
        }
    }
    
    func startTrackingUserLocation() {
        mapview.showsUserLocation = true
        centerViewOnUserLocation()
        locationManager.startUpdatingLocation()
        previousLocation = getCenterLocation(for: mapview)
    }

    
    func getCenterLocation(for mapView: MKMapView) -> CLLocation {
        let latitude = mapview.centerCoordinate.latitude
        let longitude = mapview.centerCoordinate.longitude
        
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    func getDirections() {
        guard let location = locationManager.location?.coordinate else {
            //TODO: Inform user we don't have their current location
            return
        }
        
        let request = createDirectionsRequest(from: location)
        let directions = MKDirections(request: request)
        resetMapView(withNew: directions)
        
        directions.calculate { [unowned self] (response, error) in
            //TODO: Handle error if needed
            guard let response = response else { return } //TODO: Show response not available in an alert
            
            for route in response.routes {
                //Draw polyline on map
                self.mapview.addOverlay(route.polyline)
                //Ensure that the entire route fits on the screen
                self.mapview.setVisibleMapRect(route.polyline.boundingMapRect, animated: true)
            }
        }
    }
    
    
    func createDirectionsRequest(from coordinate: CLLocationCoordinate2D) -> MKDirections.Request {
        let destinationCoordinate       = getCenterLocation(for: mapview).coordinate
        let startingLocation            = MKPlacemark(coordinate: coordinate)
        let destination                 = MKPlacemark(coordinate: destinationCoordinate)
        
        let request                     = MKDirections.Request()
        request.source                  = MKMapItem(placemark: startingLocation)
        request.destination             = MKMapItem(placemark: destination)
        request.transportType           = .automobile
        request.requestsAlternateRoutes = true
        
        return request
    }
    
    
    func resetMapView(withNew directions: MKDirections) {
        mapview.removeOverlays(mapview.overlays)
        directionsArray.append(directions)
        let _ = directionsArray.map {
            $0.cancel()
            directionsArray.remove(at: directionsArray.firstIndex(of: $0)!)
        }
    }



}

extension ViewController: CLLocationManagerDelegate {
    
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        guard let location = locations.last else { return }
//        let center = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
//        let region  = MKCoordinateRegion.init(center: center, latitudinalMeters: regionInMeters, longitudinalMeters: regionInMeters)
//        mapview.setRegion(region, animated: true)
//    }
//
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        checklocationAuthorization()
    }
}

extension ViewController: MKMapViewDelegate {

func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    let center = getCenterLocation(for: mapview)
    
    guard let previousLocation = self.previousLocation else { return }
    
    //Ensure that the user moves the map above a threshold of 50
    guard center.distance(from: previousLocation) > 50 else { return }
    self.previousLocation = center
    
    //Cancel any pending reverse location geocoding requests.
    geoCoder.cancelGeocode()
    
    geoCoder.reverseGeocodeLocation(center) { [weak self] (placemarks, error) in
        guard let self = self else { return }
        
        if let _ = error {
            //TODO: Show alert informing the user
            return
        }
        
        guard let placemark = placemarks?.first else {
            //TODO: Show alert informing the user
            return
        }
        
        let streetNumber = placemark.subThoroughfare ?? ""
        let streetName = placemark.thoroughfare ?? ""
        
        DispatchQueue.main.async {
            self.addressLabel.text = "\(streetNumber) \(streetName)"
        }
    }
}


func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    //Get the polyline rendered on the screen
    let renderer = MKPolylineRenderer(overlay: overlay as! MKPolyline)
    //change the polyline color
    renderer.strokeColor = .blue
    
    return renderer
}
}
