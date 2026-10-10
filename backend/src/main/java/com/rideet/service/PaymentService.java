package com.rideet.service;

import com.rideet.domain.entity.Payment;
import com.rideet.domain.entity.Ride;
import com.rideet.domain.enums.PaymentMethod;
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

    @Value("${stripe.currency:usd}")
    private String chargeCurrency;

    private final PaymentRepository paymentRepository;
    private final RideRepository rideRepository;

    @PostConstruct
    public void init() {
        Stripe.apiKey = stripeSecretKey;
    }

    @Transactional
    public Map<String, String> createPaymentIntent(Long passengerUserId, Long rideId) {
        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));
        if (!ride.getPassenger().getId().equals(passengerUserId)) {
            throw new BadRequestException("Only the passenger pays for a ride");
        }
        if (ride.getPaymentMethod() == PaymentMethod.CASH) {
            throw new BadRequestException("This ride is paid in cash");
        }
        if (isTestKey(stripeSecretKey)) {
            throw new BadRequestException("Payments are not configured on this server");
        }

        // The fare charged is the fare actually measured once the trip is done; while the
        // ride is still running the estimate is all there is to bill against.
        double payable = ride.getActualFare() != null ? ride.getActualFare() : ride.getEstimatedFare();
        long amountCents = (long) (payable * 100);

        try {
            PaymentIntentCreateParams params = PaymentIntentCreateParams.builder()
                    .setAmount(amountCents)
                    .setCurrency(chargeCurrency)
                    .putMetadata("rideId", rideId.toString())
                    .putMetadata("passengerId", ride.getPassenger().getId().toString())
                    .build();

            PaymentIntent intent = PaymentIntent.create(params);

            Payment payment = Payment.builder()
                    .ride(ride)
                    .passenger(ride.getPassenger())
                    .amount(payable)
                    .paymentMethod(ride.getPaymentMethod())
                    .stripePaymentIntentId(intent.getId())
                    .status(PaymentStatus.PENDING)
                    .build();
            paymentRepository.save(payment);

            Map<String, String> result = new HashMap<>();
            result.put("clientSecret", intent.getClientSecret());
            result.put("paymentIntentId", intent.getId());
            result.put("amount", String.valueOf(payable));
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
        if (payment.getStatus() == PaymentStatus.COMPLETED) {
            return; // Stripe retries deliveries; a replay must not be a second charge
        }
        payment.setStatus(PaymentStatus.COMPLETED);
        payment.setPaidAt(LocalDateTime.now());
        paymentRepository.save(payment);
        log.info("Payment confirmed for ride {}", payment.getRide().getId());
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getPaymentStatus(Long userId, Long rideId) {
        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new ResourceNotFoundException("Ride not found"));
        boolean participant = ride.getPassenger().getId().equals(userId)
                || (ride.getDriver() != null && ride.getDriver().getUser().getId().equals(userId));
        if (!participant) {
            throw new BadRequestException("You are not a participant of this ride");
        }

        Map<String, Object> view = new HashMap<>();
        view.put("rideId", rideId);
        view.put("amount", ride.getActualFare() != null ? ride.getActualFare() : ride.getEstimatedFare());
        view.put("paymentMethod", ride.getPaymentMethod());
        paymentRepository.findByRideId(rideId).ifPresent(p -> {
            view.put("status", p.getStatus());
            view.put("paidAt", p.getPaidAt());
            view.put("paymentIntentId", p.getStripePaymentIntentId());
        });
        return view;
    }

    private boolean isTestKey(String key) {
        return key == null || key.isBlank() || key.startsWith("sk_test_your");
    }
}
