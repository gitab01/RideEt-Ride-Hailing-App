package com.rideet.controller;

import com.rideet.dto.response.ApiResponse;
import com.rideet.domain.entity.User;
import com.rideet.service.PaymentService;
import com.stripe.exception.SignatureVerificationException;
import com.stripe.model.Event;
import com.stripe.model.PaymentIntent;
import com.stripe.net.Webhook;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/payments")
@RequiredArgsConstructor
@Slf4j
public class PaymentController {

    private final PaymentService paymentService;

    @Value("${stripe.webhook-secret}")
    private String webhookSecret;

    @PostMapping("/rides/{rideId}/create-intent")
    public ResponseEntity<ApiResponse<Map<String, String>>> createPaymentIntent(
            @AuthenticationPrincipal User user,
            @PathVariable Long rideId) {

        Map<String, String> result = paymentService.createPaymentIntent(user.getId(), rideId);
        return ResponseEntity.ok(ApiResponse.success(result));
    }

    @GetMapping("/rides/{rideId}/status")
    public ResponseEntity<ApiResponse<Map<String, Object>>> paymentStatus(
            @AuthenticationPrincipal User user,
            @PathVariable Long rideId) {

        return ResponseEntity.ok(ApiResponse.success(paymentService.getPaymentStatus(user.getId(), rideId)));
    }

    /**
     * Stripe's own callback. This path is anonymous, so the signature is the only proof the
     * request came from Stripe; without it verified anyone could mark a ride paid.
     */
    @PostMapping("/webhook")
    public ResponseEntity<String> handleStripeWebhook(@RequestBody String payload,
                                                      @RequestHeader("Stripe-Signature") String sigHeader) {
        Event event;
        try {
            event = Webhook.constructEvent(payload, sigHeader, webhookSecret);
        } catch (SignatureVerificationException e) {
            log.warn("Rejected Stripe webhook with a bad signature: {}", e.getMessage());
            return ResponseEntity.badRequest().body("Invalid signature");
        }

        if ("payment_intent.succeeded".equals(event.getType())) {
            PaymentIntent intent = (PaymentIntent) event.getDataObjectDeserializer()
                    .getObject()
                    .orElse(null);
            if (intent != null) {
                paymentService.confirmPayment(intent.getId());
            }
        } else {
            log.debug("Ignoring Stripe event type {}", event.getType());
        }
        return ResponseEntity.ok("Received");
    }
}
