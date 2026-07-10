package com.rideet.controller;

import com.rideet.dto.response.ApiResponse;
import com.rideet.service.PaymentService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/payments")
@RequiredArgsConstructor
public class PaymentController {

    private final PaymentService paymentService;

    @PostMapping("/rides/{rideId}/create-intent")
    public ResponseEntity<ApiResponse<Map<String, String>>> createPaymentIntent(@PathVariable Long rideId) {
        Map<String, String> result = paymentService.createPaymentIntent(rideId);
        return ResponseEntity.ok(ApiResponse.success(result));
    }

    @PostMapping("/webhook")
    public ResponseEntity<String> handleStripeWebhook(@RequestBody String payload,
                                                       @RequestHeader("Stripe-Signature") String sigHeader) {
        // In production: verify the webhook signature with Stripe
        // For now just confirm payment if event is payment_intent.succeeded
        try {
            if (payload.contains("payment_intent.succeeded")) {
                // Extract payment_intent id from payload and confirm
                // paymentService.confirmPayment(paymentIntentId);
            }
            return ResponseEntity.ok("Received");
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Webhook Error");
        }
    }
}
