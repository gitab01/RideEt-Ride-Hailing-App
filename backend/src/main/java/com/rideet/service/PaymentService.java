package com.rideet.service;

import com.rideet.domain.entity.Payment;
import com.rideet.domain.entity.Ride;
import com.rideet.domain.enums.PaymentStatus;
import com.rideet.exception.BadRequestException;
import com.rideet.exception.ResourceNotFoundException;
import com.rideet.repository.PaymentRepository;
import com.rideet.repository.RideRepository;
import com.stripe.Stripe;
import com.stripe.exception.StripeException;
import com.stripe.model.PaymentIntent;
import com.stripe.param.PaymentIntentCreateParams;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class PaymentService {

    @Value("${stripe.secret-key}")
    private String stripeSecretKey;

    private final PaymentRepository paymentRepository;
    private final RideRepository rideRepository;

    @PostConstruct
    public void init() {
        Stripe.apiKey = stripeSecretKey;
    }

    @Transactional
    public Map<String, String> createPaymentIntent(Long rideId) {
        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));

        long amountCents = (long) (ride.getEstimatedFare() * 100);

        try {
            PaymentIntentCreateParams params = PaymentIntentCreateParams.builder()
                    .setAmount(amountCents)
                    .setCurrency("usd")
                    .putMetadata("rideId", rideId.toString())
                    .putMetadata("passengerId", ride.getPassenger().getId().toString())
                    .build();

            PaymentIntent intent = PaymentIntent.create(params);

            Payment payment = Payment.builder()
                    .ride(ride)
                    .passenger(ride.getPassenger())
                    .amount(ride.getEstimatedFare())
                    .paymentMethod(ride.getPaymentMethod())
                    .stripePaymentIntentId(intent.getId())
                    .status(PaymentStatus.PENDING)
                    .build();
            paymentRepository.save(payment);

            Map<String, String> result = new HashMap<>();
            result.put("clientSecret", intent.getClientSecret());
            result.put("paymentIntentId", intent.getId());
            return result;

        } catch (StripeException e) {
            log.error("Stripe error creating payment intent for ride {}: {}", rideId, e.getMessage());
            throw new BadRequestException("Payment processing failed: " + e.getMessage());
        }
    }

    @Transactional
    public void confirmPayment(String paymentIntentId) {
        Payment payment = paymentRepository.findByStripePaymentIntentId(paymentIntentId)
                .orElseThrow(() -> new ResourceNotFoundException("Payment not found"));

        payment.setStatus(PaymentStatus.COMPLETED);
        payment.setPaidAt(LocalDateTime.now());
        paymentRepository.save(payment);
        log.info("Payment confirmed for ride {}", payment.getRide().getId());
    }

    public Payment getPaymentByRideId(Long rideId) {
        return paymentRepository.findByRideId(rideId)
                .orElseThrow(() -> new ResourceNotFoundException("Payment not found"));
    }
}
